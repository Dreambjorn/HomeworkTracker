-- HomeworkTracker - General DB
local addonName, addon = ...

addon:RegisterDatabaseInit("general", function()
    -- Initialize global currencies
    addon.currencyDB = addon.currencyDB or {}
    table.insert(addon.currencyDB, { name = "Community Coupons", id = 3363, icon = 134495 })
    table.insert(addon.currencyDB, { name = "Restored Coffer Key", id = 3028, icon = 4622270 })
    table.insert(addon.currencyDB, { name = "Coffer Key Shards", id = 3310, icon = 133016})
    table.insert(addon.currencyDB, { name = "Undercoin", id = 2803, icon = 133858 })
    -- Define global categories
    addon.categoryInfo = addon.categoryInfo or {}

    -- Set color for season progress
    addon.categoryInfo["seasonProgress"] = { color = {0.5,0.5,0.5} }
    -- Add season progress trackers
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
        { name = "Adventurer Dawncrest", id = 3383, icon = 7639517, cap = 120 },
        { name = "Veteran Dawncrest",    id = 3341, icon = 7639525, cap = 120 },
        { name = "Champion Dawncrest",   id = 3343, icon = 7639519, cap = 120 },
        { name = "Hero Dawncrest",       id = 3345, icon = 7639521, cap = 120 },
        { name = "Myth Dawncrest",       id = 3347, icon = 7639523, cap = 120 },
    }
    for _, v in ipairs(dawnCrests) do table.insert(addon.crestDB, v) end

    -- Initialize default database settings
    if addon.defaults then
        addon.defaults.crests = addon.defaults.crests or { enable = true }
        addon.defaults.crests.showAdventurer = true
        addon.defaults.crests.showVeteran = true
        addon.defaults.crests.showChampion = true
        addon.defaults.crests.showHero = true
        addon.defaults.crests.showMyth = true
        addon.defaults.currency = addon.defaults.currency or { enable = true }
        addon.defaults.currency[3363] = true  -- Community Coupons
        addon.defaults.currency[3028] = true  -- Restored Coffer Key
        addon.defaults.currency[3310] = true  -- Coffer Key Shards
        addon.defaults.currency[2803] = true  -- Undercoin
        addon.majorCities = addon.majorCities or {
            -- Vanilla
            [84] = true,    -- Stormwind City
            [85] = true,    -- Orgrimmar
            [87] = true,    -- Ironforge
            [89] = true,    -- Darnassus
            [88] = true,    -- Thunder Bluff
            [90] = true,    -- Undercity

            -- Burning Crusade
            [103] = true,   -- The Exodar
            [110] = true,   -- Silvermoon City
            [111] = true,   -- Shattrath City

            -- Wrath of the Lich King
            [125] = true,   -- Dalaran

            -- Mists of Pandaria
            [390] = true,   -- Shrine of the Seven Stars
            [392] = true,   -- Shrine of Two Moons

            -- Warlords of Draenor
            [622] = true,   -- Stormshield
            [624] = true,   -- Warspear

            -- Legion
            [627] = true,   -- Dalaran

            -- Battle for Azeroth
            [1161] = true,  -- Boralus
            [1165] = true,  -- Dazar'alor

            -- Shadowlands
            [1670] = true,  -- Oribos

            -- Dragonflight
            [2112] = true,  -- Valdrakken

            -- The War Within 
            [2339] = true,  -- Dornogal

            -- Midnight
            [2393] = true,  -- Silvermoon
        }
    end
end)