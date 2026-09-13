-- HomeworkTracker - Diagnostics
local addonName, addon = ...

local prof = {
    active = false,
    seconds = 0,
    session = 0,
    builds = 0,
    skipped = 0,
    total = 0,
    max = 0,
    rows = 0,
    burst = 0,
    burstTime = 0,
    last = nil,
    sameRows = 0,
    sameTime = 0,
    lastRows = nil,
    byReason = {},
    bySection = {},
    bySectionRows = {},
    partial = 0,
    fallback = 0,
    empty = 0,
    activityTicks = 0,
    activityTotal = 0,
    activityMax = 0,
    eventPrepCalls = 0,
    eventPrepTotal = 0,
    eventPrepMax = 0,
    byEventPrep = {},
    vaultWaitFrames = 0,
    vaultWaitTotal = 0,
    vaultWaitMax = 0,
}

local diagnosticsWindow
local pendingDiagnostics
local lastDiagnostics
local ShowDiagnosticsWindow
local combatWatcher

local function GetCombatWatcher()
    if combatWatcher then return combatWatcher end

    combatWatcher = CreateFrame("Frame")
    combatWatcher:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if diagnosticsWindow and diagnosticsWindow:IsShown() then
                pendingDiagnostics = lastDiagnostics
                diagnosticsWindow:Hide()
                self:RegisterEvent("PLAYER_REGEN_ENABLED")
            end
            return
        end

        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        local pending = pendingDiagnostics
        pendingDiagnostics = nil
        if pending then ShowDiagnosticsWindow(pending.title, pending.rows) end
    end)
    return combatWatcher
end

local function AddHeading(rows, text)
    rows[#rows + 1] = { left = text, header = true }
end

local function AddValue(rows, label, value, indent)
    rows[#rows + 1] = { left = label, right = value, indent = indent or 0 }
end

local function AddText(rows, text)
    rows[#rows + 1] = { left = text }
end

local function AddSpacer(rows)
    rows[#rows + 1] = { spacer = true }
end

local function TakeDiagnosticRow(frame, index)
    local row = frame.rows[index]
    if row then return row end

    row = CreateFrame("Frame", nil, frame.content)
    row.left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.left:SetJustifyH("LEFT")
    row.left:SetJustifyV("MIDDLE")
    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.right:SetJustifyH("RIGHT")
    row.right:SetJustifyV("MIDDLE")
    frame.rows[index] = row
    return row
end

local function ApplyDiagnosticFont(fontString, header)
    if header then
        addon:SetFont(fontString, addon:GetHeaderFontKey(), addon:GetHeaderFontSize(),
            HomeworkTrackerDB.headerFontOutline)
        fontString:SetTextColor(1, 0.82, 0, 1)
    else
        addon:SetFont(fontString, addon:GetFontKey(), addon:GetFontSize(), HomeworkTrackerDB.fontOutline)
        fontString:SetTextColor(1, 1, 1, 1)
    end
end

local function RenderDiagnosticRows(frame, rows)
    local y = 4
    for index, entry in ipairs(rows) do
        local row = TakeDiagnosticRow(frame, index)
        row:ClearAllPoints()
        row.left:ClearAllPoints()
        row.right:ClearAllPoints()

        if entry.spacer then
            row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 4, -y)
            row:SetPoint("TOPRIGHT", frame.content, "TOPRIGHT", -4, -y)
            row:SetHeight(8)
            row.left:Hide()
            row.right:Hide()
        else
            local height = math.max(18, (entry.header and addon:GetHeaderFontSize() or addon:GetFontSize()) + 5)
            row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 4 + (entry.indent or 0) * 14, -y)
            row:SetPoint("TOPRIGHT", frame.content, "TOPRIGHT", -4, -y)
            row:SetHeight(height)
            ApplyDiagnosticFont(row.left, entry.header)
            ApplyDiagnosticFont(row.right, entry.header)
            row.left:Show()
            row.right:Show()
            row.left:SetText(entry.left or "")
            row.right:SetText(entry.right or "")
            row.left:SetPoint("LEFT")
            if entry.right then
                row.right:SetPoint("RIGHT")
                row.left:SetPoint("RIGHT", row.right, "LEFT", -14, 0)
            else
                row.left:SetPoint("RIGHT")
            end
        end
        row:Show()
        y = y + row:GetHeight()
    end

    for index = #rows + 1, #frame.rows do frame.rows[index]:Hide() end
    frame.content:SetHeight(math.max(1, y + 4))
end

ShowDiagnosticsWindow = function(title, rows)
    lastDiagnostics = { title = title, rows = rows }
    if InCombatLockdown and InCombatLockdown() then
        pendingDiagnostics = lastDiagnostics
        GetCombatWatcher():RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    if not diagnosticsWindow then
        local frame = CreateFrame("Frame", "HomeworkTrackerDiagnosticsWindow", UIParent, "BackdropTemplate")
        frame:SetSize(590, 340)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        frame.title:SetPoint("TOPLEFT", 14, -12)
        frame.title:SetPoint("TOPRIGHT", -38, -12)
        frame.title:SetJustifyH("LEFT")

        frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")

        frame.scrollFrame = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
        frame.scrollFrame:SetPoint("TOPLEFT", 12, -40)
        frame.scrollFrame:SetPoint("BOTTOMRIGHT", -36, 12)
        frame.scrollFrame.ScrollBar:ClearAllPoints()
        frame.scrollFrame.ScrollBar:SetPoint("TOPLEFT", frame.scrollFrame, "TOPRIGHT", 10, 2)
        frame.scrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", frame.scrollFrame, "BOTTOMRIGHT", 10, 5)
        frame.close:SetPoint("RIGHT", frame.title, "RIGHT", 28, 0)

        frame.content = CreateFrame("Frame", nil, frame.scrollFrame)
        frame.content:SetSize(500, 1)
        frame.scrollFrame:SetScrollChild(frame.content)
        frame.scrollFrame:SetScript("OnSizeChanged", function(_, width)
            frame.content:SetWidth(width)
        end)
        frame.rows = {}
        frame:SetScript("OnHide", function()
            if combatWatcher then combatWatcher:UnregisterEvent("PLAYER_REGEN_DISABLED") end
        end)

        tinsert(UISpecialFrames, "HomeworkTrackerDiagnosticsWindow")
        diagnosticsWindow = frame
    end

    pendingDiagnostics = nil
    local watcher = GetCombatWatcher()
    watcher:UnregisterEvent("PLAYER_REGEN_ENABLED")
    addon:SetFont(diagnosticsWindow.title, addon:GetHeaderFontKey(), addon:GetHeaderFontSize(),
        HomeworkTrackerDB.headerFontOutline)
    diagnosticsWindow.title:SetTextColor(1, 0.82, 0, 1)
    diagnosticsWindow.title:SetText("Homework Tracker - " .. title)
    RenderDiagnosticRows(diagnosticsWindow, rows)
    diagnosticsWindow.scrollFrame:SetVerticalScroll(0)
    diagnosticsWindow:Show()
    diagnosticsWindow:Raise()
    watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
end

local function ReadMetric(metric)
    if not (C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric and metric) then return nil end
    local ok, value = pcall(C_AddOnProfiler.GetAddOnMetric, addonName, metric)
    if ok and type(value) == "number" then return value end
    return nil
end

local function AddBlizzardMetrics(rows)
    local metrics = Enum and Enum.AddOnProfilerMetric
    if not metrics then return end

    local session = ReadMetric(metrics.SessionAverageTime)
    local recent = ReadMetric(metrics.RecentAverageTime)
    local peak = ReadMetric(metrics.PeakTime)
    if not (session or recent or peak) then return end

    AddHeading(rows, "Blizzard profiler")
    if session and C_AddOnProfiler.GetApplicationMetric and C_AddOnProfiler.GetOverallMetric then
        local application = C_AddOnProfiler.GetApplicationMetric(metrics.SessionAverageTime)
        local overall = C_AddOnProfiler.GetOverallMetric(metrics.SessionAverageTime)
        local relative = application - overall + session
        if relative > 0 then
            AddValue(rows, "CPU share, session", ("%.2f%%"):format(100 * session / relative))
        end
    end
    if session then AddValue(rows, "Session average", ("%.4f ms/tick"):format(session)) end
    if recent then AddValue(rows, "Recent average", ("%.4f ms/tick"):format(recent)) end
    if peak then AddValue(rows, "Session peak", ("%.2f ms"):format(peak)) end

    local over1 = ReadMetric(metrics.CountTimeOver1Ms)
    local over5 = ReadMetric(metrics.CountTimeOver5Ms)
    local over10 = ReadMetric(metrics.CountTimeOver10Ms)
    if over1 then
        AddValue(rows, "Session spikes", (">1ms %d  |  >5ms %d  |  >10ms %d")
            :format(over1, over5 or 0, over10 or 0))
    end
end

function addon:RecordActivityTimer(started)
    if not started or not prof.active then return end
    local elapsed = debugprofilestop() - started
    prof.activityTicks = prof.activityTicks + 1
    prof.activityTotal = prof.activityTotal + elapsed
    if elapsed > prof.activityMax then prof.activityMax = elapsed end
end

function addon:RecordEventPreparation(event, started)
    if not started or not prof.active then return end
    local elapsed = debugprofilestop() - started
    prof.eventPrepCalls = prof.eventPrepCalls + 1
    prof.eventPrepTotal = prof.eventPrepTotal + elapsed
    if elapsed > prof.eventPrepMax then prof.eventPrepMax = elapsed end
    local data = prof.byEventPrep[event]
    if not data then
        data = { count = 0, total = 0 }
        prof.byEventPrep[event] = data
    end
    data.count = data.count + 1
    data.total = data.total + elapsed
end

function addon:RecordVaultWait(started)
    if not started or not prof.active then return end
    local elapsed = debugprofilestop() - started
    prof.vaultWaitFrames = prof.vaultWaitFrames + 1
    prof.vaultWaitTotal = prof.vaultWaitTotal + elapsed
    if elapsed > prof.vaultWaitMax then prof.vaultWaitMax = elapsed end
end

local function ReportProfiling()
    local elapsed = prof.startedAt and (GetTime() - prof.startedAt) or prof.seconds
    local rows = {}
    AddValue(rows, "Profiling interval", ("%.0f seconds"):format(elapsed))
    AddSpacer(rows)
    AddBlizzardMetrics(rows)
    AddSpacer(rows)
    AddHeading(rows, "Tracker rebuilds")

    if prof.builds == 0 then
        AddValue(rows, "No rebuilds", ("%d skipped while hidden"):format(prof.skipped))
    else
        AddValue(rows, "Rebuilds", ("%d  |  %.2f ms average  |  %.2f ms maximum")
            :format(prof.builds, prof.total / prof.builds, prof.max))
        AddValue(rows, "Rows", ("%d drawn  |  %d skipped while hidden"):format(prof.rows, prof.skipped))
        AddValue(rows, "Same-frame rebuilds", ("%d  |  %.2f ms total"):format(prof.burst, prof.burstTime))
        AddValue(rows, "Same-row rebuilds", ("%d  |  %.2f ms total"):format(prof.sameRows, prof.sameTime))
        AddValue(rows, "Incremental rebuilds", ("%d partial  |  %d full fallbacks"):format(prof.partial, prof.fallback))
        AddValue(rows, "No-change redraws skipped", ("%d"):format(prof.empty))

        local ranked = {}
        for reason, count in pairs(prof.byReason) do ranked[#ranked + 1] = { reason, count } end
        table.sort(ranked, function(a, b) return a[2] > b[2] end)
        AddSpacer(rows)
        AddHeading(rows, "Rebuild reasons")
        for i = 1, math.min(5, #ranked) do
            AddValue(rows, ranked[i][1], ("%d rebuilds"):format(ranked[i][2]))
        end

        local sections = {}
        for name, ms in pairs(prof.bySection) do sections[#sections + 1] = { name, ms } end
        table.sort(sections, function(a, b) return a[2] > b[2] end)
        AddSpacer(rows)
        AddHeading(rows, "Section rebuilds")
        for i = 1, #sections do
            local name = sections[i][1]
            AddValue(rows, name, ("%.2f ms  |  %d rows")
                :format(sections[i][2], prof.bySectionRows[name] or 0), 1)
        end
    end

    AddSpacer(rows)
    AddHeading(rows, "Background work")
    AddValue(rows, "Activity timers", ("%d ticks  |  %.2f ms total  |  %.2f ms maximum")
        :format(prof.activityTicks, prof.activityTotal, prof.activityMax))
    AddValue(rows, "Event preparation", ("%d calls  |  %.2f ms total  |  %.2f ms maximum")
        :format(prof.eventPrepCalls, prof.eventPrepTotal, prof.eventPrepMax))

    local preparation = {}
    for event, data in pairs(prof.byEventPrep) do preparation[#preparation + 1] = { event, data } end
    table.sort(preparation, function(a, b) return a[2].total > b[2].total end)
    for i = 1, math.min(5, #preparation) do
        local event, data = preparation[i][1], preparation[i][2]
        AddValue(rows, event, ("%d calls  |  %.2f ms"):format(data.count, data.total), 1)
    end

    AddValue(rows, "Vault wait", ("%d frames  |  %.2f ms total  |  %.2f ms maximum")
        :format(prof.vaultWaitFrames, prof.vaultWaitTotal, prof.vaultWaitMax))

    prof.active = false
    addon._profile = nil
    if prof.timer then
        prof.timer:Cancel()
        prof.timer = nil
    end
    ShowDiagnosticsWindow("Profiling", rows)
end

-- Profiling: sample addon work, then open one reusable results window
function addon:StartProfiling(seconds)
    if prof.active then
        ReportProfiling()
        return
    end

    pendingDiagnostics = nil
    if combatWatcher then
        combatWatcher:UnregisterEvent("PLAYER_REGEN_ENABLED")
        combatWatcher:UnregisterEvent("PLAYER_REGEN_DISABLED")
    end
    if diagnosticsWindow then diagnosticsWindow:Hide() end
    prof.active, prof.seconds, prof.startedAt = true, seconds, GetTime()
    addon._profile = prof
    prof.builds, prof.skipped, prof.total, prof.max, prof.rows = 0, 0, 0, 0, 0
    prof.burst, prof.burstTime, prof.last = 0, 0, nil
    prof.partial, prof.fallback = 0, 0
    prof.sameRows, prof.sameTime, prof.lastRows = 0, 0, nil
    prof.empty = 0
    prof.activityTicks, prof.activityTotal, prof.activityMax = 0, 0, 0
    prof.eventPrepCalls, prof.eventPrepTotal, prof.eventPrepMax = 0, 0, 0
    prof.vaultWaitFrames, prof.vaultWaitTotal, prof.vaultWaitMax = 0, 0, 0
    wipe(prof.byReason)
    wipe(prof.bySection)
    wipe(prof.bySectionRows)
    wipe(prof.byEventPrep)
    prof.session = prof.session + 1
    local session = prof.session
    print(("|cff4db2ffHomeworkTracker:|r profiling for %ds, /hw profiling again to stop early"):format(seconds))
    prof.timer = C_Timer.NewTimer(seconds, function()
        if prof.active and prof.session == session then
            prof.timer = nil
            ReportProfiling()
        end
    end)
end

-- Debug: verify incremental redraws and pooled-row ownership
function addon:DebugRows()
    local debugRows = self._debugRows
    if not (debugRows and self.mainFrame and self.modules) then return end
    if not (self.sectionEndY and next(self.sectionEndY)) then
        ShowDiagnosticsWindow("Debug", { { left = "Nothing drawn yet; open tracker first." } })
        return
    end
    if not self.mainFrame:IsShown() then
        ShowDiagnosticsWindow("Debug", { { left = "Tracker is hidden; nothing to redraw." } })
        return
    end

    local details = {}
    local stale, was, now = debugRows.CountStaleRows(self, details)
    local rows = {}
    for _, detail in ipairs(details) do AddText(rows, detail) end
    AddValue(rows, "Stale rows", ("%d  |  %d before  |  %d after"):format(stale, was, now))

    local worst, worstName, tested = 0, nil, 0
    for _, mod in ipairs(self.modules) do
        local name = mod.name
        if self.sectionEndY[name] then
            self.sectionEndY[name] = self.sectionEndY[name] - 1
            self:UpdateDisplay({ [name] = true })
            tested = tested + 1
            local orphans = debugRows.CountOrphanRows(self)
            if orphans > worst then worst, worstName = orphans, name end
        end
    end

    self:UpdateDisplay()
    local orphans, total = debugRows.CountOrphanRows(self)
    AddValue(rows, "Forced fallbacks", ("%d  |  worst left %d orphaned%s")
        :format(tested, worst, worstName and (" (" .. worstName .. ")") or ""))
    AddValue(rows, "Final rows", ("%d orphaned  |  %d drawn  |  %d created")
        :format(orphans, #self.sections, total))
    ShowDiagnosticsWindow("Debug", rows)
end
