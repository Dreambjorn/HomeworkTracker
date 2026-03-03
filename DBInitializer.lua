-- HomeworkTracker - DBInitializer
local addonName, addon = ...

-- Define database initializers
addon.dbInitializers = addon.dbInitializers or {}
addon.dbInitMap = addon.dbInitMap or {}

-- Register a DB initializer
function addon:RegisterDatabaseInit(key, fn)
    if type(key) ~= "string" or type(fn) ~= "function" then
        error("RegisterDatabaseInit requires (string, function)")
    end

    if self.dbInitMap[key] then
        for i, entry in ipairs(self.dbInitializers) do
            if entry.key == key then
                entry.fn = fn
                self.dbInitMap[key] = fn
                return
            end
        end
        self.dbInitMap[key] = fn
        return
    end

    table.insert(self.dbInitializers, { key = key, fn = fn })
    self.dbInitMap[key] = fn
end

-- Run all DB initializers
function addon:RunDatabaseInit()
    for _, entry in ipairs(self.dbInitializers) do
        local ok, err = pcall(entry.fn, self)
        if not ok then
            print(("HomeworkTracker: database init '%s' failed: %s"):format(entry.key, tostring(err)))
        end
    end
end
