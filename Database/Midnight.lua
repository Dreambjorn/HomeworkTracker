-- HomeworkTracker - Midnight DB
local addonName, addon = ...

addon:RegisterDatabaseInit("midnight", function()
    -- Initialize defaults
    if addon.defaults then
        -- Currency defaults
        addon.defaults.currency = addon.defaults.currency or { enable = true }
        local currencyDefaults = {
            [3316] = true,  -- Voidlight Marl
            [3392] = true,  -- Remnant of Anguish
            [3376] = true,  -- Shard of Dundun
            [3379] = true,  -- Brimming Arcana
            [3377] = true,  -- Unalloyed Abundance
            [3385] = true,  -- Luminous Dust
            [259361] = true, -- Vile Essence
            [255826] = true, -- Mysterious Skyshards
        }
        for id, val in pairs(currencyDefaults) do
            addon.defaults.currency[id] = val
        end

        -- Timed activities
        addon.defaults.activities = addon.defaults.activities or {}
        addon.defaults.activities.stormarionAssault = true
    end

    -- Map IDs
    addon.expansionMapIDs = addon.expansionMapIDs or {}
    addon.expansionMapIDs.midnight = {
        [2537] = true, -- Quel'Thalas
        [2395] = true, -- Eversong Woods
        [2424] = true, -- Isle of Quel'Danas
        [2437] = true, -- Zul'Aman
        [2413] = true, -- Harandar
        [2405] = true, -- Voidstorm
    }

    -- Zone IDs
    addon.zoneIDs = addon.zoneIDs or {}
    local midnightIDs = {
        ["Quel'Thalas"]         = 2537,
        ["Eversong Woods"]      = 2395,
        ["Isle of Quel'Danas"]  = 2424,
        ["Zul'Aman"]            = 2437,
        ["Harandar"]            = 2413,
        ["Voidstorm"]           = 2405,
    }
    for k, v in pairs(midnightIDs) do addon.zoneIDs[k] = v end

    -- Zone categories
    addon.zoneCategoryMap = addon.zoneCategoryMap or {}
    local midnightZoneCats = {
        ["Quel'Thalas"]         = "quelthalas",
        ["Eversong Woods"]      = "eversong",
        ["Isle of Quel'Danas"]  = "queldanas",
        ["Zul'Aman"]            = "zulaman",
        ["Harandar"]            = "harandar",
        ["Voidstorm"]           = "voidstorm",

    }
    for k, v in pairs(midnightZoneCats) do addon.zoneCategoryMap[k] = v end

    -- Zone priorities
    addon.zonePriority = addon.zonePriority or {}
    local midnightZones = {
        ["Quel'Thalas"]         = 1,
        ["Eversong Woods"]      = 2,
        ["Isle of Quel'Danas"]  = 3,
        ["Zul'Aman"]            = 4,
        ["Harandar"]            = 5,
        ["Voidstorm"]           = 6,
    }
    for k, v in pairs(midnightZones) do addon.zonePriority[k] = v end

    -- Categories
    addon.categoryInfo = addon.categoryInfo or {}
    if not addon.categoryInfo["general"] then
        addon.categoryInfo["general"] = { order = 1, color = addon.defaultColors.general or {0.255, 0.439, 0.929} }
    end
    local midnightCategories = {
        ["quelthalas"]    = { order = 2, color = {0.77, 0.12, 0.23} },
        ["eversong"]      = { order = 3, color = {0.35, 0.75, 0.40} },
        ["queldanas"]     = { order = 4, color = {0.77, 0.12, 0.23} },
        ["zulaman"]       = { order = 5, color = {0.70, 0.45, 0.20} },
        ["harandar"]      = { order = 6, color = {0.30, 0.55, 0.20} },
        ["voidstorm"]     = { order = 7, color = {0.45, 0.15, 0.65} },
        ["delves"]        = { order = 8, color = (addon.defaultColors and addon.defaultColors.delves) or {0.85, 0.65, 0.20} },
    }
    for k, v in pairs(midnightCategories) do addon.categoryInfo[k] = v end

    -- Activity colors
    if addon.defaultColors then
        addon.defaultColors.activities = addon.defaultColors.activities or {}
        local midnightActivityColors = {
            stormarionAssault = {0.45, 0.15, 0.65},
        }
        for k, v in pairs(midnightActivityColors) do
            addon.defaultColors.activities[k] = v
        end
    end

    -- Zone colors
    if addon.defaultColors then
        addon.defaultColors.zones = addon.defaultColors.zones or {}
        local midnightColors = {
            quelthalas = {0.77, 0.12, 0.23},
            queldanas  = {0.77, 0.12, 0.23},
            eversong   = {0.35, 0.75, 0.40},
            zulaman    = {0.70, 0.45, 0.20},
            harandar   = {0.30, 0.55, 0.20},
            voidstorm  = {0.45, 0.15, 0.65},
        }
        for k, v in pairs(midnightColors) do
            addon.defaultColors.zones[k] = v
        end
        addon.defaultColors.delves = addon.defaultColors.delves or {0.85, 0.65, 0.20}
    end

    -- Event timers
    local midnightEvents = {
        -- Stormarion Assault (every 30 min)
        ["stormarionAssault"] = {
            ["name"] = { ["enUS"] = "Stormarion Assault" },
            ["alert"] = 1,
            ["questReq"] = 2,
            ["questID"] = { 90962, 94581 },
            ["color"] = { 115, 38, 166 },
            ["interval"] = 1800, -- 30 minutes
            ["duration"] = 900,  -- 15 minutes active
            ["epoch"] = {
                [1] = 1772370083, -- North America
                [2] = 1772370083, -- Korea
                [3] = 1772370083, -- Europe
                [4] = 1772370083, -- Taiwan
                [5] = 1772370083, -- China
            },
        },
    }

    addon.eventDB = addon.eventDB or {}
    for k, v in pairs(midnightEvents) do
        v.expansion = "midnight"
        addon.eventDB[k] = v
    end

    -- Weekly quests
    local midnightWeekly = {
        { name = "World Boss", questID = {92636, 92560, 92034, 92123}, questType = "single", isWeekend = false, category = "general", 
          bossNames = {[92636] = "Predaxas", [92560] = "Lu'ashal", [92034] = "Thorm'belan", [92123] = "Cragpine"} },
        { name = "Abundance", questID = {89507}, questType = "simple", isWeekend = false, category = "general" },
        { name = "Lost Legends", questID = {89268}, questType = "simple", isWeekend = false, category = "harandar" },
        { name = "Stormarion Assault", questID = {90962}, questType = "simple", isWeekend = false, category = "voidstorm" },
        { name = "Stand Your Ground", questID = {94581}, questType = "simple", isWeekend = false, category = "voidstorm" },
    }
    addon.weeklyDB = addon.weeklyDB or {}
    for _, v in ipairs(midnightWeekly) do
        v.expansion = "midnight"
        table.insert(addon.weeklyDB, v)
    end

    -- Rares
    local midnightRares = {
        -- Harandar
        { name = "Rhazul", npcID = 248741, questID = 91832, zone = "Harandar", x = 51.17, y = 45.30 },
        { name = "Chironex", npcID = 249844, questID = 92137, zone = "Harandar", x = 68.01, y = 40.33 },
        { name = "Ha'kalawe", npcID = 249849, questID = 92142, zone = "Harandar", x = 67.69, y = 62.28 },
        { name = "Tallcap the Truthspreader", npcID = 249902, questID = 92148, zone = "Harandar", x = 72.63, y = 69.26 },
        { name = "Queen Lashtongue", npcID = 249962, questID = 92154, zone = "Harandar", x = 60.10, y = 47.01 },
        { name = "Chlorokyll", npcID = 249997, questID = 92161, zone = "Harandar", x = 64.90, y = 48.10 },
        { name = "Stumpy", npcID = 250086, questID = 92168, zone = "Harandar", x = 65.65, y = 32.79 },
        { name = "Serrasa", npcID = 250180, questID = 92170, zone = "Harandar", x = 56.78, y = 34.22 },
        { name = "Mindrot", npcID = 250226, questID = 92172, zone = "Harandar", x = 46.35, y = 32.84 },
        { name = "Dracaena", npcID = 250231, questID = 92176, zone = "Harandar", x = 40.65, y = 42.99 },
        { name = "Treetop", npcID = 250246, questID = 92183, zone = "Harandar", x = 36.59, y = 75.16 },
        { name = "Oro'ohna", npcID = 250317, questID = 92190, zone = "Harandar", x = 28.11, y = 81.81 },
        { name = "Pterrock", npcID = 250321, questID = 92191, zone = "Harandar", x = 27.19, y = 70.21 },
        { name = "Ahl'ua'huhi", npcID = 250347, questID = 92193, zone = "Harandar", x = 39.69, y = 60.70 },
        { name = "Annulus the Worldshaker", npcID = 250358, questID = 92194, zone = "Harandar", x = 44.50, y = 16.10 },

        -- Voidstorm
        { name = "Sundereth the Caller", npcID = 244272, questID = 90805, zone = "Voidstorm", x = 29.51, y = 50.08 },
        { name = "Territorial Voidscythe", npcID = 238498, questID = 91050, zone = "Voidstorm", x = 34.02, y = 82.18 },
        { name = "Tremora", npcID = 241443, questID = 91048, zone = "Voidstorm", x = 36.30, y = 83.73 },
        { name = "Screammaxa the Matriarch", npcID = 256922, questID = 93966, zone = "Voidstorm", x = 43.68, y = 51.51 },
        { name = "Bane of the Vilebloods", npcID = 256923, questID = 93946, zone = "Voidstorm", x = 47.05, y = 80.63 },
        { name = "Aeonelle Blackstar", npcID = 256924, questID = 93944, zone = "Voidstorm", x = 39.24, y = 63.94 },
        { name = "Lotus Darkblossom", npcID = 256925, questID = 93947, zone = "Voidstorm", x = 37.88, y = 71.78 },
        { name = "Queen o' War", npcID = 256926, questID = 93934, zone = "Voidstorm", x = 55.72, y = 79.45 },
        { name = "Ravengerus", npcID = 256808, questID = 93895, zone = "Voidstorm", x = 48.81, y = 53.17 },
        { name = "Bilemaw the Gluttonous", npcID = 256770, questID = 93884, zone = "Voidstorm", x = 35.48, y = 50.23 },
        { name = "Nightbrood", npcID = 245044, questID = 91051, zone = "Voidstorm", x = 40.15, y = 41.19 },
        { name = "Far'thana the Mad", npcID = 256821, questID = 93896, zone = "Voidstorm", x = 53.94, y = 62.72 },
        { name = "Voidseer Orivane", npcID = 248791, questID = 94459, zone = "Voidstorm", x = 30.57, y = 66.61 },
        { name = "The Many-Broken", npcID = 248459, questID = 94458, zone = "Voidstorm", x = 28.82, y = 70.24 },
        { name = "Abysslick", npcID = 248700, questID = 94462, zone = "Voidstorm", x = 28.15, y = 65.93 },
        { name = "Nullspiral", npcID = 248068, questID = 94460, zone = "Voidstorm", x = 29.80, y = 67.87 },

        -- Zul'Aman
        { name = "Necrohexxer Raz'ka", npcID = 242023, questID = 89569, zone = "Zul'Aman", x = 34.39, y = 33.04 },
        { name = "The Snapping Scourge", npcID = 242024, questID = 89570, zone = "Zul'Aman", x = 51.88, y = 18.75 },
        { name = "Skullcrusher Harak", npcID = 242025, questID = 89571, zone = "Zul'Aman", x = 51.84, y = 72.92 },
        { name = "Elder Oaktalon", npcID = 242026, questID = 89572, zone = "Zul'Aman", x = 33.68, y = 88.97 },
        { name = "Depthborn Eelamental", npcID = 242027, questID = 89573, zone = "Zul'Aman", x = 47.66, y = 20.52 },
        { name = "Lightwood Borer", npcID = 242028, questID = 89575, zone = "Zul'Aman", x = 28.83, y = 24.50 },
        { name = "Spinefrill", npcID = 242031, questID = 89578, zone = "Zul'Aman", x = 30.57, y = 44.56 },
        { name = "Oophaga", npcID = 242032, questID = 89579, zone = "Zul'Aman", x = 46.55, y = 51.27 },
        { name = "Tiny Vermin", npcID = 242033, questID = 89580, zone = "Zul'Aman", x = 47.76, y = 34.35 },
        { name = "Voidtouched Crustacean", npcID = 242034, questID = 89581, zone = "Zul'Aman", x = 21.54, y = 70.51 },
        { name = "The Devouring Invader", npcID = 242035, questID = 89583, zone = "Zul'Aman", x = 39.59, y = 20.97 },
        { name = "Mrrlokk", npcID = 245975, questID = 91174, zone = "Zul'Aman", x = 50.86, y = 65.17 },
        { name = "The Decaying Diamondback", npcID = 245691, questID = 91072, zone = "Zul'Aman", x = 46.39, y = 43.39 },
        { name = "Ash'an the Empowered", npcID = 245692, questID = 91073, zone = "Zul'Aman", x = 45.28, y = 41.71 },
        { name = "Poacher Rav'ik", npcID = 247976, questID = 91634, zone = "Zul'Aman", x = 82.97, y = 21.45 },

        -- Eversong Woods
        { name = "Warden of Weeds", npcID = 246332, questID = 91280, zone = "Eversong Woods", x = 52.62, y = 75.32 },
        { name = "Harried Hawkstrider", npcID = 246633, questID = 91315, zone = "Eversong Woods", x = 45.09, y = 77.60 },
        { name = "Overfester Hydra", npcID = 240129, questID = 92392, zone = "Eversong Woods", x = 54.71, y = 60.19 },
        { name = "Bloated Snapdragon", npcID = 250582, questID = 92366, zone = "Eversong Woods", x = 36.56, y = 64.07 },
        { name = "Cre'van", npcID = 250719, questID = 92391, zone = "Eversong Woods", x = 62.96, y = 48.78 },
        { name = "Coralfang", npcID = 250683, questID = 92389, zone = "Eversong Woods", x = 36.33, y = 36.36 },
        { name = "Lady Liminus", npcID = 250754, questID = 92393, zone = "Eversong Woods", x = 36.65, y = 77.19 },
        { name = "Terrinor", npcID = 250876, questID = 92409, zone = "Eversong Woods", x = 40.40, y = 85.32 },
        { name = "Bad Zed", npcID = 250841, questID = 92404, zone = "Eversong Woods", x = 49.04, y = 87.77 },
        { name = "Waverly", npcID = 250780, questID = 92395, zone = "Eversong Woods", x = 34.81, y = 20.98 },
        { name = "Banuran", npcID = 250826, questID = 92403, zone = "Eversong Woods", x = 56.42, y = 77.60 },
        { name = "Lost Guardian", npcID = 250806, questID = 92399, zone = "Eversong Woods", x = 59.10, y = 79.24 },
        { name = "Duskburn", npcID = 255302, questID = 93550, zone = "Eversong Woods", x = 42.17, y = 68.97 },
        { name = "Malfunctioning Construct", npcID = 255329, questID = 93555, zone = "Eversong Woods", x = 51.69, y = 46.01 },
        { name = "Dame Bloodshed", npcID = 255348, questID = 93561, zone = "Eversong Woods", x = 44.57, y = 38.17 },

        -- Isle of Quel'Danas
        { name = "Tarhu the Ransacker", npcID = 252465, questID = 95011, zone = "Isle of Quel'Danas", x = 55.71, y = 29.13 },
        { name = "Dripping Shadow", npcID = 239864, questID = 95010, zone = "Isle of Quel'Danas", x = 37.09, y = 38.30 },
    }

    addon.raresDB = addon.raresDB or {}
    for _, v in ipairs(midnightRares) do
        v.expansion = "midnight"
        table.insert(addon.raresDB, v)
    end

    -- Delves Database
    local midnightDelves = {
        { name = "Collegiate Calamity", delveID = 8426, zone = "Silvermoon City", x = 31.07, y = 27.33 },
        { name = "The Darkway", delveID = 8440, zone = "Silvermoon City", x = 95.00, y = 5.00 },
        { name = "The Shadow Enclave", delveID = 8438, zone = "Eversong Woods", x = 47.24, y = 4.68 },
        { name = "Parhelion Plaza", delveID = 8428, zone = "Isle of Quel'Danas", x = 42.80, y = 36.12 },
        { name = "Atal'Aman", delveID = 8444, zone = "Zul'Aman", x = 85.63, y = 13.85 },
        { name = "Twilight Crypts", delveID = 8442, zone = "Zul'Aman", x = 10.57, y = 8.41 },
        { name = "The Grudge Pit", delveID = 8434, zone = "Harandar", x = 50.49, y = 5.88 },
        { name = "The Gulf of Memory", delveID = 8436, zone = "Harandar", x = 55.20, y = 26.80 },
        { name = "Shadowguard Point", delveID = 8432, zone = "Voidstorm", x = 18.14, y = 84.33 },
        { name = "Sunkiller Sanctum", delveID = 8430, zone = "Voidstorm", x = 19.67, y = 56.68 },
    }
    addon.delvesDB = addon.delvesDB or {}
    for _, v in ipairs(midnightDelves) do
        table.insert(addon.delvesDB, v)
    end

    -- Currencies
    local midnightCurrencies = {
        -- General
        { name = "Voidlight Marl", id = 3316, icon = 7137586 },
        { name = "Remnant of Anguish", id = 3392, icon = 4554435 },

        -- Eversong Wood
        { name = "Brimming Arcana", id = 3379, icon = 132849 },

        -- Zul'Aman
        { name = "Shard of Dundun", id = 3376, icon = 134569 },
        { name = "Unalloyed Abundance", id = 3377, icon = 5041790 },
        { name = "Vile Essence", id = 259361, icon = 132871, max = 1000, isItem = true },
        
        -- Harandar
        { name = "Luminous Dust", id = 3385, icon = 133852 },
        { name = "Mysterious Skyshards", id = 255826, icon = 429385, max = 500, isItem = true },
    }
    addon.currencyDB = addon.currencyDB or {}
    for _, v in ipairs(midnightCurrencies) do
        v.expansion = "midnight"
        table.insert(addon.currencyDB, v)
    end

    -- Reputations
    local midnightReputations = {
        { name = "Silvermoon Court", id = 2710, category = "quelthalas", order = 1 },
        { name = "Magisters", id = 2711, category = "quelthalas", order = 1.1 },
        { name = "Blood Knights", id = 2712, category = "quelthalas", order = 1.2 },
        { name = "Farstriders", id = 2713, category = "quelthalas", order = 1.3 },
        { name = "Shades of the Row", id = 2714, category = "quelthalas", order = 1.4 },
        { name = "The Amani Tribe", id = 2696, category = "zulaman", order = 2 },
        { name = "Hara'ti", id = 2704, category = "harandar", order = 3 },
        { name = "The Singularity", id = 2699, category = "voidstorm", order = 4 },
        { name = "Valeera Sanguinar", id = 2744, category = "delves", order = 5 },
    }
    addon.reputationDB = addon.reputationDB or {}
    for _, v in ipairs(midnightReputations) do
        v.expansion = "midnight"
        table.insert(addon.reputationDB, v)
    end

    -- Reputation grouping
    addon.reputationParentMap = addon.reputationParentMap or {}
    addon.reputationParentMap[2710] = {2711, 2712, 2713, 2714} -- Silvermoon Court -> Magisters, Blood Knights, Farstriders, Shades of the Row

    addon.reputationSortOrder = addon.reputationSortOrder or {}
    for _, v in ipairs(midnightReputations) do
        if v.order then addon.reputationSortOrder[v.id] = v.order end
    end
end)
