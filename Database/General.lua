-- HomeworkTracker - General DB
local addonName, addon = ...

addon:RegisterDatabaseInit("general", function()
    -- Initialize global currencies
    addon.currencyDB = addon.currencyDB or {}
    table.insert(addon.currencyDB, { name = "Community Coupons", id = 3363, icon = 134495 })

    -- Define global categories
    addon.categoryInfo = addon.categoryInfo or {}
    -- Set fallback order for season progress
    addon.categoryInfo["seasonProgress"] = { color = {0.5,0.5,0.5} }

    -- Add general progress trackers
    addon.progressDB = addon.progressDB or {}
    local generalProgress = {
        { name = "Delves: Season 1", id = 2742, category = "seasonProgress", order = 1 },
        { name = "Prey: Season 1", id = 2764, category = "seasonProgress", order = 2 },
    }
    for _, v in ipairs(generalProgress) do
        table.insert(addon.progressDB, v)
    end

    -- Add crest currencies
    addon.crestDB = addon.crestDB or {}
    local dawnCrests = {
        { name = "Veteran Dawncrest", id = 3341, icon = 7639525, cap = 120 },
        { name = "Champion Dawncrest", id = 3343, icon = 7639519, cap = 120 },
        { name = "Hero Dawncrest", id = 3345, icon = 7639521, cap = 120 },
    }
    for _, v in ipairs(dawnCrests) do table.insert(addon.crestDB, v) end

    -- Initialize default database settings
    if addon.defaults then
        addon.defaults.crests = addon.defaults.crests or { enable = true }
        addon.defaults.crests.showHero = true
        addon.defaults.crests.showChampion = true
        addon.defaults.crests.showVeteran = true

        addon.defaults.currency = addon.defaults.currency or { enable = true }
        addon.defaults.currency[3363] = true
    end
end)