-- HomeworkTracker - Minimap Button (uses LibDBIcon when available)
local addonName, addon = ...

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

-- Use the addon's TOC IconTexture if available (numeric ID), otherwise fallback
local ICON_TEXTURE = 647701

-- Local reference to created LDB object / button
addon._minimapDataObject = addon._minimapDataObject or nil

-- The saved-vars table LibDBIcon reads and writes, made if the profile has none
local function MinimapDB()
    HomeworkTrackerDB = HomeworkTrackerDB or {}
    if type(HomeworkTrackerDB.minimap) ~= "table" then
        HomeworkTrackerDB.minimap = {}
    end
    return HomeworkTrackerDB.minimap
end

-- showMinimapButton is the setting the config writes; hide is what the library reads
local function SyncHideFlag(db)
    if HomeworkTrackerDB.showMinimapButton == false then
        db.hide = true
    else
        db.hide = nil
    end
end

function addon:InitMinimapButton()
    if self._minimapInit then return end
    self._minimapInit = true

    HomeworkTrackerDB = HomeworkTrackerDB or {}
    HomeworkTrackerDB.minimap = HomeworkTrackerDB.minimap or {}

    if LDB and LDBIcon then
        if not self._minimapDataObject then
            local obj = LDB:NewDataObject("HomeworkTracker", {
                type = "data source",
                text = "Homework Tracker",
                ---@diagnostic disable-next-line: assign-type-mismatch
                icon = ICON_TEXTURE,
                OnClick = function(_, button)
                    if button == "LeftButton" then
                        HomeworkTrackerDB = HomeworkTrackerDB or {}
                        HomeworkTrackerDB.enabled = HomeworkTrackerDB.enabled ~= true
                        if addon.UpdateDisplay then addon:UpdateDisplay() end
                        if addon._enabledCheckbox then addon._enabledCheckbox.check:SetChecked(HomeworkTrackerDB.enabled == true) end
                    elseif button == "RightButton" then
                        if addon.OpenConfig then addon:OpenConfig() end
                    end
                end,
                OnTooltipShow = function(tt)
                    if not tt or not tt.AddLine then return end
                    tt:AddLine("Homework Tracker", 1, 1, 1)
                    tt:AddLine("Left-Click: Toggle tracker", 1, 0.6, 0)
                    tt:AddLine("Right-Click: Open configuration", 1, 0.6, 0)
                end,
            })
            self._minimapDataObject = obj
        end

        local db = MinimapDB()
        SyncHideFlag(db)

        -- Register with LibDBIcon (uses HomeworkTrackerDB.minimap for persistence)
        LDBIcon:Register("HomeworkTracker", self._minimapDataObject, db)
    else
        -- No LibDBIcon available; create simple Minimap button fallback
        if not self.minimapButton and Minimap then
            local btn = CreateFrame("Button", "HomeworkTrackerMinimapButton", Minimap)
            btn:SetSize(28, 28)
            btn:SetFrameStrata("MEDIUM")
            btn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -6, 6)
            btn:EnableMouse(true)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexture(ICON_TEXTURE)
            btn.icon = tex

            btn:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then
                    HomeworkTrackerDB = HomeworkTrackerDB or {}
                    HomeworkTrackerDB.enabled = HomeworkTrackerDB.enabled ~= true
                    if addon.UpdateDisplay then addon:UpdateDisplay() end
                    if addon._enabledCheckbox then addon._enabledCheckbox.check:SetChecked(HomeworkTrackerDB.enabled == true) end
                elseif button == "RightButton" then
                    if addon.OpenConfig then addon:OpenConfig() end
                end
            end)

            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText("Homework Tracker", 1, 1, 1)
                GameTooltip:AddLine("Left-Click: Toggle tracker", 1, 0.6, 0)
                GameTooltip:AddLine("Right-Click: Open configuration", 1, 0.6, 0)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            self.minimapButton = btn
        end
    end

    -- Ensure visibility matches saved setting
    if self.UpdateMinimapButtonVisibility then
        self:UpdateMinimapButtonVisibility()
    end
end

-- Rebind the library to the live table, since a profile switch replaces it
function addon:RefreshMinimapButton()
    if not (LDBIcon and self._minimapDataObject) then return end
    if not LDBIcon:IsRegistered("HomeworkTracker") then return end

    local db = MinimapDB()

    -- Carry the shown position over, so a fresh profile does not snap the button
    if db.minimapPos == nil then
        local button = LDBIcon:GetMinimapButton("HomeworkTracker")
        ---@diagnostic disable-next-line: undefined-field
        local shown = button and ((button.db and button.db.minimapPos) or button.minimapPos)
        if shown then db.minimapPos = shown end
    end

    SyncHideFlag(db)
    LDBIcon:Refresh("HomeworkTracker", db)
end

function addon:UpdateMinimapButtonVisibility()
    local show = true
    if addon.IsMinimapButtonEnabled then
        show = addon:IsMinimapButtonEnabled()
    else
        if HomeworkTrackerDB and HomeworkTrackerDB.showMinimapButton ~= nil then
            show = HomeworkTrackerDB.showMinimapButton
        elseif addon.defaults and addon.defaults.showMinimapButton ~= nil then
            show = addon.defaults.showMinimapButton
        end
    end

    if LDBIcon and self._minimapDataObject then
        MinimapDB().hide = not show

        if show then
            LDBIcon:Show("HomeworkTracker")
        else
            LDBIcon:Hide("HomeworkTracker")
        end
    else
        if self.minimapButton then
            if show then
                self.minimapButton:Show()
            else
                self.minimapButton:Hide()
            end
        end
    end
end
