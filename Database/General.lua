-- HomeworkTracker - General DB
local addonName, addon = ...

addon:RegisterDatabaseInit("general", function()
    -- Initialize global currencies
    addon.currencyDB = addon.currencyDB or {}
    table.insert(addon.currencyDB, { name = "Community Coupons", id = 3363, icon = 134495 })
    table.insert(addon.currencyDB, { name = "Restored Coffer Key", id = 3028, icon = 4622270 })
    table.insert(addon.currencyDB, { name = "Coffer Key Shards", id = 3310, icon = 133016})
    table.insert(addon.currencyDB, { name = "Undercoin", id = 2803, icon = 133858 })
    -- World events run on the calendar, so they belong to no expansion
    addon.eventDB = addon.eventDB or {}
    local worldEvents = {
        -- Seasonal holidays
        ["lunarFestival"] = {
            ["name"] = "Lunar Festival",
            ["holidayNames"] = { "Lunar Festival" },
            ["holidayID"] = { 327 },
            ["color"] = { 0.47, 0.63, 0.86 },
        },
        ["loveIsInTheAir"] = {
            ["name"] = "Love is in the Air",
            ["holidayNames"] = { "Love is in the Air" },
            ["holidayID"] = { 335, 423 },
            ["color"] = { 0.82, 0.31, 0.51 },
        },
        ["noblegarden"] = {
            ["name"] = "Noblegarden",
            ["holidayNames"] = { "Noblegarden" },
            ["holidayID"] = { 181 },
            ["color"] = { 0.47, 0.78, 0.47 },
        },
        ["childrensWeek"] = {
            ["name"] = "Children's Week",
            ["holidayNames"] = { "Children's Week" },
            ["holidayID"] = { 201 },
            ["color"] = { 0.90, 0.71, 0.35 },
        },
        ["midsummer"] = {
            ["name"] = "Midsummer Fire Festival",
            ["holidayNames"] = { "Midsummer Fire Festival" },
            ["holidayID"] = { 341 },
            ["color"] = { 0.90, 0.47, 0.20 },
        },
        ["brewfest"] = {
            ["name"] = "Brewfest",
            ["holidayNames"] = { "Brewfest" },
            ["holidayID"] = { 372 },
            ["color"] = { 0.78, 0.59, 0.24 },
        },
        ["hallowsEnd"] = {
            ["name"] = "Hallow's End",
            ["holidayNames"] = { "Hallow's End" },
            ["holidayID"] = { 324, 1405 },
            ["color"] = { 0.86, 0.43, 0.12 },
        },
        ["dayOfTheDead"] = {
            ["name"] = "Day of the Dead",
            ["holidayNames"] = { "Day of the Dead" },
            ["holidayID"] = { 409 },
            ["color"] = { 0.71, 0.35, 0.63 },
        },
        ["pilgrimsBounty"] = {
            ["name"] = "Pilgrim's Bounty",
            ["holidayNames"] = { "Pilgrim's Bounty" },
            ["holidayID"] = { 404 },
            ["color"] = { 0.75, 0.51, 0.27 },
        },
        ["winterVeil"] = {
            ["name"] = "Feast of Winter Veil",
            ["holidayNames"] = { "Feast of Winter Veil" },
            ["holidayID"] = { 141 },
            ["color"] = { 0.78, 0.24, 0.24 },
        },
        ["darkmoonFaire"] = {
            ["name"] = "Darkmoon Faire",
            ["holidayNames"] = { "Darkmoon Faire" },
            ["holidayID"] = { 479 },
            ["color"] = { 0.59, 0.35, 0.71 },
        },

        ["harvestFestival"] = {
            ["name"] = "Harvest Festival",
            ["holidayNames"] = { "Harvest Festival" },
            ["holidayID"] = { 321 },
            ["color"] = { 0.85, 0.65, 0.30 },
        },
        ["anniversary"] = {
            ["name"] = "WoW Anniversary",
            -- The recurring entries plus the next numbered one
            ["holidayNames"] = { "WoW's Anniversary", "WoW's 22nd Anniversary" },
            ["holidayID"] = { 590, 1587, 1588, 1589, 1590, 1808 },
            ["color"] = { 0.95, 0.80, 0.35 },
        },

        -- Rotating weekly like the bonus events, so these share a row as well
        ["pvpBrawl"] = {
            ["name"] = "PvP Brawl",
            ["holidayNames"] = {
                "PvP Brawl: Arathi Blizzard",
                "PvP Brawl: Battleground Blitz",
                "PvP Brawl: Classic Ashran",
                "PvP Brawl: Comp Stomp",
                "PvP Brawl: Cooking Impossible",
                "PvP Brawl: Deep Six",
                "PvP Brawl: Deepwind Dunk",
                "PvP Brawl: Gravity Lapse",
                "PvP Brawl: Packed House",
                "PvP Brawl: Shado-Pan Showdown",
                "PvP Brawl: Solo Shuffle",
                "PvP Brawl: Southshore vs. Tarren Mill",
                "PvP Brawl: Temple of Hotmogu",
                "PvP Brawl: Warsong Scramble",
            },
            ["holidayID"] = {
                659, 660, 662, 663, 664, 666, 667, 669, 670, 671, 673, 674,
                676, 677, 678, 680, 681, 683, 684, 685, 687, 688, 701, 702,
                704, 705, 706, 736, 737, 1047, 1048, 1049, 1050, 1051, 1120, 1121,
                1122, 1123, 1124, 1166, 1167, 1168, 1169, 1170, 1221, 1232, 1233, 1234,
                1235, 1236, 1237, 1238, 1239, 1240, 1241, 1242, 1243, 1244, 1245, 1246,
                1307, 1308, 1309, 1310, 1311, 1312, 1408, 1452, 1453, 1454, 1455,
            },
            ["color"] = { 0.75, 0.30, 0.30 },
        },
        ["racingCup"] = {
            ["name"] = "Racing Cup",
            ["holidayNames"] = {
                "Kalimdor Cup",
                "Eastern Kingdoms Cup",
                "Outland Cup",
                "Northrend Cup",
            },
            ["holidayID"] = { 1395, 1400, 1407, 1429 },
            ["color"] = { 0.40, 0.70, 0.85 },
        },

        -- Only one bonus event runs per week, so they share a row
        ["bonusEvent"] = {
            ["name"] = "Bonus Event",
            ["holidayNames"] = {
                addon:GetCurrentDungeonEventName(),
                "World Quest Bonus Event",
                "Pet Battle Bonus Event",
                "Battleground Bonus Event",
                "Arena Skirmish Bonus Event",
                "Delves Bonus Event",
            },
            ["holidayID"] = {
                561, 563, 565, 592, 599, 600, 601, 602, 603, 604, 610, 611,
                612, 613, 614, 615, 1559, 1560, 1561, 1562, 1802, 1803, 1804, 1805,
            },
            ["color"] = { 0.31, 0.59, 0.78 },
        },

        -- One calendar title covers every expansion, so the ID names it
        ["timewalking"] = {
            ["name"] = "Timewalking",
            ["holidayNames"] = { "Timewalking Dungeon Event" },
            ["holidayID"] = {
                559, 562, 587, 616, 617, 618, 622, 623, 624, 628, 629, 630,
                643, 652, 654, 656, 1056, 1063, 1065, 1068, 1263, 1265, 1267, 1269,
                1271, 1273, 1275, 1277, 1508, 1583, 1584, 1585, 1666, 1667, 1668, 1669,
                1703, 1704, 1705, 1706, 1707, 1708, 1709, 1710, 1719, 1720, 1721, 1722,
            },
            ["holidayLabels"] = {
                [559] = "Burning Crusade",
                [622] = "Burning Crusade",
                [623] = "Burning Crusade",
                [624] = "Burning Crusade",
                [562] = "Wrath of the Lich King",
                [616] = "Wrath of the Lich King",
                [617] = "Wrath of the Lich King",
                [618] = "Wrath of the Lich King",
                [587] = "Cataclysm",
                [628] = "Cataclysm",
                [629] = "Cataclysm",
                [630] = "Cataclysm",
                [643] = "Mists of Pandaria",
                [652] = "Mists of Pandaria",
                [654] = "Mists of Pandaria",
                [656] = "Mists of Pandaria",
                [1056] = "Warlords of Draenor",
                [1063] = "Warlords of Draenor",
                [1065] = "Warlords of Draenor",
                [1068] = "Warlords of Draenor",
                [1263] = "Legion",
                [1265] = "Legion",
                [1267] = "Legion",
                [1269] = "Legion",
                [1271] = "Legion",
                [1273] = "Legion",
                [1275] = "Legion",
                [1277] = "Legion",
                [1508] = "Classic",
                [1583] = "Classic",
                [1584] = "Classic",
                [1585] = "Classic",
                [1666] = "Battle for Azeroth",
                [1667] = "Battle for Azeroth",
                [1668] = "Battle for Azeroth",
                [1669] = "Battle for Azeroth",
                [1703] = "Shadowlands",
                [1704] = "Shadowlands",
                [1705] = "Shadowlands",
                [1706] = "Shadowlands",
                [1707] = "Shadowlands",
                [1708] = "Shadowlands",
                [1709] = "Shadowlands",
                [1710] = "Shadowlands",
                [1719] = "Dragonflight",
                [1720] = "Dragonflight",
                [1721] = "Dragonflight",
                [1722] = "Dragonflight",
            },
            ["color"] = { 0.31, 0.59, 0.78 },
        },
        ["windsOfFortune"] = {
            ["name"] = "Winds of Mysterious Fortune",
            ["holidayNames"] = { "Winds of Mysterious Fortune" },
            ["holidayID"] = { 1636, 1670, 1671, 1672, 1683 },
            ["color"] = { 0.55, 0.78, 0.86 },
        },
    }
    for k, v in pairs(worldEvents) do addon.eventDB[k] = v end

    if addon.defaultColors then
        addon.defaultColors.activities = addon.defaultColors.activities or {}
        local worldEventColors = {
            lunarFestival = { 0.47, 0.63, 0.86 },
            loveIsInTheAir = { 0.82, 0.31, 0.51 },
            noblegarden = { 0.47, 0.78, 0.47 },
            childrensWeek = { 0.90, 0.71, 0.35 },
            midsummer = { 0.90, 0.47, 0.20 },
            brewfest = { 0.78, 0.59, 0.24 },
            hallowsEnd = { 0.86, 0.43, 0.12 },
            dayOfTheDead = { 0.71, 0.35, 0.63 },
            pilgrimsBounty = { 0.75, 0.51, 0.27 },
            winterVeil = { 0.78, 0.24, 0.24 },
            darkmoonFaire = { 0.59, 0.35, 0.71 },
            bonusEvent = { 0.31, 0.59, 0.78 },
            timewalking = { 0.31, 0.59, 0.78 },
            windsOfFortune = { 0.55, 0.78, 0.86 },
            harvestFestival = { 0.85, 0.65, 0.30 },
            anniversary = { 0.95, 0.80, 0.35 },
            pvpBrawl = { 0.75, 0.30, 0.30 },
            racingCup = { 0.40, 0.70, 0.85 },
        }
        for k, v in pairs(worldEventColors) do addon.defaultColors.activities[k] = v end
    end

    -- Timewalking names the expansion it is running, so the bar can take its colour
    addon.expansionColors = {
        ["Classic"]                = { 0.85, 0.72, 0.38 },
        ["Burning Crusade"]        = { 0.35, 0.62, 0.22 },
        ["Wrath of the Lich King"] = { 0.55, 0.85, 0.95 },
        ["Cataclysm"]              = { 0.90, 0.42, 0.15 },
        ["Mists of Pandaria"]      = { 0.30, 0.78, 0.55 },
        ["Warlords of Draenor"]    = { 0.65, 0.35, 0.25 },
        ["Legion"]                 = { 0.55, 0.95, 0.25 },
        ["Battle for Azeroth"]     = { 0.40, 0.60, 0.82 },
        ["Shadowlands"]            = { 0.80, 0.20, 0.30 },
        ["Dragonflight"]           = { 0.75, 0.78, 0.82 },
    }

    if addon.defaults then
        addon.defaults.activities = addon.defaults.activities or {}
        addon.defaults.activities.darkmoonFaire = true
        addon.defaults.activities.windsOfFortune = true
        addon.defaults.activities.bonusEvent = true
        addon.defaults.activities.timewalking = true
    end

    -- Define global categories
    addon.categoryInfo = addon.categoryInfo or {}

    -- Set color for season progress
    addon.categoryInfo["seasonProgress"] = { color = {0.5,0.5,0.5} }
    -- Add season progress trackers
    addon.progressDB = addon.progressDB or {}
    local generalProgress = {
        { name = "Delves: Season 2", id = 2796, category = "seasonProgress", order = 1 },
        { name = "Prey: Season 2", id = 2808, category = "seasonProgress", order = 2 },
    }
    for _, v in ipairs(generalProgress) do
        table.insert(addon.progressDB, v)
    end

    -- Add crest currencies
    addon.crestDB = addon.crestDB or {}
    local mistCrests = {
        { name = "Adventurer Mistcrest", id = 3442, icon = 7734054, cap = 100 },
        { name = "Veteran Mistcrest",    id = 3443, icon = 7734062, cap = 100 },
        { name = "Champion Mistcrest",   id = 3444, icon = 7734056, cap = 100 },
        { name = "Hero Mistcrest",       id = 3445, icon = 7734058, cap = 100 },
        { name = "Myth Mistcrest",       id = 3446, icon = 7734060, cap = 100 },
    }
    for _, v in ipairs(mistCrests) do table.insert(addon.crestDB, v) end

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