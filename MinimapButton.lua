-- HomeworkTracker - Minimap Button (uses LibDBIcon when available)
local addonName, addon = ...

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

-- Use the addon's TOC IconTexture if available (numeric ID), otherwise fallback
local ICON_TEXTURE = 647701

-- Local reference to created LDB object / button
addon._minimapDataObject = addon._minimapDataObject or nil

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
                icon = ICON_TEXTURE,
                OnClick = function(_, button)
                    if button == "LeftButton" then
                        HomeworkTrackerDB = HomeworkTrackerDB or {}
                        HomeworkTrackerDB.enabled = not (HomeworkTrackerDB.enabled == true)
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

        if HomeworkTrackerDB.showMinimapButton == false then
            HomeworkTrackerDB.minimap.hide = true
        else
            HomeworkTrackerDB.minimap.hide = nil
        end

        -- Register with LibDBIcon (uses HomeworkTrackerDB.minimap for persistence)
        LDBIcon:Register("HomeworkTracker", self._minimapDataObject, HomeworkTrackerDB.minimap)
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
                    HomeworkTrackerDB.enabled = not (HomeworkTrackerDB.enabled == true)
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
        HomeworkTrackerDB = HomeworkTrackerDB or {}
        HomeworkTrackerDB.minimap = HomeworkTrackerDB.minimap or {}
        HomeworkTrackerDB.minimap.hide = not show

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
