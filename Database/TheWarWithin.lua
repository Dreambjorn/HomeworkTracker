-- HomeworkTracker - TWW DB
local addonName, addon = ...

addon:RegisterDatabaseInit("theWarWithin", function()
    -- Initialize defaults
    if addon.defaults then
        -- Currency defaults
        addon.defaults.currency = addon.defaults.currency or { enable = true }
        local currencyDefaults = {
            [2815] = true,  -- Resonance Crystals
            [3310] = false, -- Coffer Key Shards
            [3303] = false, -- Untethered Coin
            [3056] = false, -- Kej
            [3055] = false, -- Mereldar Derby Mark
            [3093] = false, -- Nerub-ar Finery
            [3226] = false, -- Market Research
            [3278] = false, -- Ethereal Strands
        }
        for id, val in pairs(currencyDefaults) do
            addon.defaults.currency[id] = val
        end

        -- Default activities enabled
        addon.defaults.activities = addon.defaults.activities or {}
        addon.defaults.activities.beledarShadow = true
        addon.defaults.activities.theaterTroupe = true
        addon.defaults.activities.surgePricing = true
    end

    -- Map IDs
    addon.expansionMapIDs = addon.expansionMapIDs or {}
    addon.expansionMapIDs.theWarWithin = {
        [2274] = true, -- Khaz Algar
        [2248] = true, -- Isle of Dorn
        [2214] = true, -- Ringing Deeps
        [2215] = true, -- Hallowfall
        [2255] = true, -- Azj-Kahet
        [2346] = true, -- Undermine
        [2371] = true, -- K'aresh
        [2339] = true, -- Dornogal
    }

    -- Zone IDs
    addon.zoneIDs = addon.zoneIDs or {}
    local twwIDs = {
        ["Azj-Kahet"] = 2255,
        ["Hallowfall"] = 2215,
        ["Isle of Dorn"] = 2248,
        ["Ringing Deeps"] = 2214,
        ["Undermine"] = 2346,
        ["K'aresh"] = 2371,
    }
    for k, v in pairs(twwIDs) do addon.zoneIDs[k] = v end

    -- Zone categories
    addon.zoneCategoryMap = addon.zoneCategoryMap or {}
    local twwZoneCats = {
        ["Isle of Dorn"] = "dornogal",
        ["Ringing Deeps"] = "deeps", 
        ["Hallowfall"] = "hallowfall",
        ["Azj-Kahet"] = "azjkahet",
        ["Undermine"] = "undermine",
        ["K'aresh"] = "karesh",
    }
    for k, v in pairs(twwZoneCats) do addon.zoneCategoryMap[k] = v end
    
    -- Zone priorities
    addon.zonePriority = addon.zonePriority or {}
    local twwZones = {
        ["Isle of Dorn"] = 1,
        ["Ringing Deeps"] = 2,
        ["Hallowfall"] = 3,
        ["Azj-Kahet"] = 4,
        ["Undermine"] = 5,
        ["K'aresh"] = 6
    }
    for k, v in pairs(twwZones) do
        addon.zonePriority[k] = v
    end

    -- Categories
    addon.categoryInfo = addon.categoryInfo or {}
    if not addon.categoryInfo["general"] then
        addon.categoryInfo["general"] = { order = 1, color = addon.defaultColors.general or {0.255, 0.439, 0.929} }
    end
    
    local twwCategories = {
        ["dornogal"]   = { order = 2, color = {0.55, 0.4, 0.25} },
        ["deeps"]      = { order = 3, color = {0.04, 0.71, 0.8} },
        ["hallowfall"] = { order = 4, color = {0.94, 0.75, 0.26} },
        ["azjkahet"]   = { order = 5, color = {0.85, 0.3, 0.85} },
        ["undermine"]  = { order = 6, color = {0.2, 0.8, 0.3} },
        ["karesh"]     = { order = 7, color = {0.58, 0.51, 0.79} },
        ["delves"]     = { order = 8, color = (addon.defaultColors and addon.defaultColors.delves) or {0.85, 0.65, 0.20} },
    }
    for k, v in pairs(twwCategories) do
        addon.categoryInfo[k] = v
    end

    -- Activity colors
    if addon.defaultColors then
        addon.defaultColors.activities = addon.defaultColors.activities or {}
        local twwActivityColors = {
            beledarShadow = {0.58, 0.51, 0.79},
            theaterTroupe = {0.04, 0.71, 0.8},
            surgePricing = {0.15, 0.68, 0.38},
        }
        for k, v in pairs(twwActivityColors) do
            addon.defaultColors.activities[k] = v
        end
    end

    -- Zone colors
    if addon.defaultColors then
        addon.defaultColors.zones = addon.defaultColors.zones or {}
        local twwColors = {
            dornogal = {0.55, 0.4, 0.25},
            deeps = {0.04, 0.71, 0.8},
            hallowfall = {0.94, 0.75, 0.26},
            azjkahet = {0.85, 0.3, 0.85},
            undermine = {0.2, 0.8, 0.3},
            karesh = {0.58, 0.51, 0.79},
        }
        for k, v in pairs(twwColors) do
            addon.defaultColors.zones[k] = v
        end

        -- Ensure delves color
        addon.defaultColors.delves = addon.defaultColors.delves or {0.85, 0.65, 0.20}
    end

    -- Timed activities
    local twwEvents = {
        -- Beledar's Shadow
        ["beledarShadow"] = {
            ["name"] = {
                ["enUS"] = "Beledar's Shadow",
            },
            ["alert"] = 1,
            ["questReq"] = 1,
            ["questID"] = { 81763 },
            ["color"] = { 148, 130, 201 },
            ["interval"] = 10800, -- 3 hours
            ["duration"] = 1800,  -- 30 minutes
            ["epoch"] = { 
                [1] = 1725735600, -- North America
                [2] = 1725753600, -- Korea
                [3] = 1725728400, -- Europe
                [4] = 1725750000, -- Taiwan
                [5] = 1725753600  -- China
            }
        },
        
        -- Theater Troupe
        ["theaterTroupe"] = {
            ["name"] = {
                ["enUS"] = "Theater Troupe",
            },
            ["alert"] = 2,
            ["questReq"] = 1,
            ["questID"] = { 83240 },
            ["color"] = { 11, 182, 205 },
            ["interval"] = 3600, -- 1 hour
            ["duration"] = 600,  -- 10 minutes
            ["epoch"] = {
                [1] = 1725667200, -- North America
                [2] = 1725667200, -- Korea
                [3] = 1725667200, -- Europe
                [4] = 1725667200, -- Taiwan
                [5] = 1725667200, -- China
            }
        },

        -- Surge Pricing
        ["surgePricing"] = {
            ["name"] = { ["enUS"] = "Surge Pricing" },
            ["alert"] = 1,
            ["questReq"] = 1,
            ["questID"] = { 86775 },
            ["color"] = { 39, 174, 96 },
            ["interval"] = 3600, -- every hour
            ["duration"] = 600,  -- 10 minutes
            ["epoch"] = {
                [1] = 1725669000, -- North America
                [2] = 1725669000, -- Korea
                [3] = 1725669000, -- Europe
                [4] = 1725669000, -- Taiwan
                [5] = 1725669000, -- China
            }
        },
    }

    addon.eventDB = addon.eventDB or {}
    for k, v in pairs(twwEvents) do
        v.expansion = "theWarWithin"
        addon.eventDB[k] = v
    end
    
    -- Weekly Quests
    local twwWeekly = {
        { name = "Reduce, Reuse, Resell", questID = {85879}, questType = "simple", isWeekend = false, category = "undermine" },
        { name = "The Main Event", questID = {85088}, questType = "simple", isWeekend = false, category = "undermine" },
        { name = "Urge to Surge", questID = {86775}, questType = "simple", isWeekend = false, category = "undermine" },
        { name = "Many Jobs, Handle It!", questID = {85869}, questType = "simple", isWeekend = false, category = "undermine" },
        { name = "Adventurer's Cache", questID = {84736, 84737, 84738, 84739}, questType = "multiple", isWeekend = false, category = "general" },
        { name = "Awaken the Machine", questID = {83333}, questType = "simple", isWeekend = false, category = "deeps" },
        { name = "Hallowfall Fishing Derby", questID = {83529, 83530, 83531, 83532, 82778}, questType = "single", isWeekend = true, category = "hallowfall" },
        { name = "Rollin' Down in the Deeps", questID = {82946}, questType = "simple", isWeekend = false, category = "deeps" },
        { name = "Spreading The Light", questID = {76586}, questType = "simple", isWeekend = false, category = "hallowfall" },
        { name = "Underworld Operative", questID = {80670, 80671, 80672}, questType = "single", isWeekend = false, category = "azjkahet" },
        { name = "Weekly Dungeon", questID = {83465, 83436, 83469, 83443, 83458, 83459, 83432, 83457, 86203}, questType = "single", isWeekend = false, category = "general" },
        { name = "World Boss", questID = {82653, 81653, 81630, 81624}, questType = "single", isWeekend = false, category = "general", 
          bossNames = {[82653] = "Aggregation of Horrors", [81653] = "Shurrai", [81630] = "Kordac", [81624] = "Orta"} },
        { name = "Reshanor, the Untethered", questID = {87354}, questType = "simple", isWeekend = false, category = "karesh" },
        { name = "World Soul", questID = {82511,82453,82516,82458,82482,82483,82512,82452,82491,82494,82502,82485,82495,82503,82492,82496,82504,82488,82498,82506,82490,82499,82507,82489,82493,82501,82486,82500,82508,82487,82497,82505,82509,82659,82510,87417,87419,87422,87423,87424,89514,91855}, questType = "single", isWeekend = false, category = "general" },
        { name = "More Than Just a Phase", questID = {91093}, questType = "simple", isWeekend = false, category = "karesh" },
        { name = "Ecological Succession", questID = {85460}, questType = "simple", isWeekend = false, category = "karesh" },
    }
    
    addon.weeklyDB = addon.weeklyDB or {}
    for _, v in ipairs(twwWeekly) do
        v.expansion = "theWarWithin"
        table.insert(addon.weeklyDB, v)
    end
    
    -- Rares Database
    local twwRares = {
        -- Azj-Kahet
        { name = "Cha-tak",                          npcID = 216042, questID = 81704, zone = "Azj-Kahet",     x = 70.2, y = 21.9 },
        { name = "Deepcrawler Tx'kesh",              npcID = 222624, questID = 82077, zone = "Azj-Kahet",     x = 64.5, y = 6.7 },
        { name = "Enduring Gutterface",              npcID = 216045, questID = 81707, zone = "Azj-Kahet",     x = 58,   y = 62.2 },
        { name = "Harvester Qixt",                   npcID = 216050, questID = 82036, zone = "Azj-Kahet",     x = 65.1, y = 80.9 },
        { name = "Jix'ak the Crazed",                npcID = 216048, questID = 82034, zone = "Azj-Kahet",     x = 67.3, y = 83.2 },
        { name = "Kaheti Silk Hauler",               npcID = 221327, questID = 81702, zone = "Azj-Kahet",     x = 61.7, y = 30 },
        { name = "Maddened Siegebomber",             npcID = 216044, questID = 81706, zone = "Azj-Kahet",     x = 66.3, y = 68.5 },
        { name = "Monstrous Lasharoth",              npcID = 216043, questID = 81705, zone = "Azj-Kahet",     x = 69.9, y = 69.3 },
        { name = "Skirmisher Sa'zryk",               npcID = 216052, questID = 82078, zone = "Azj-Kahet",     x = 61,   y = 7.4 },
        { name = "The Groundskeeper",                npcID = 216038, questID = 81634, zone = "Azj-Kahet",     x = 31.2, y = 56.7 },
        { name = "The Oozekhan",                     npcID = 216049, questID = 82035, zone = "Azj-Kahet",     x = 63.3, y = 89.8 },
        { name = "Umbraclaw Matra",                  npcID = 216051, questID = 82037, zone = "Azj-Kahet",     x = 64.6, y = 3.5 },
        { name = "Xishorr",                          npcID = 216039, questID = 81701, zone = "Azj-Kahet",     x = 67.2, y = 58.4 },
        { name = "XT-Minecrusher 8700",              npcID = 216034, questID = 81703, zone = "Azj-Kahet",     x = 77.4, y = 58.9 },

        -- Hallowfall
        { name = "Beledar's Spawn",                  npcID = 207802, questID = 81763, zone = "Hallowfall",    x = 52,   y = 50.8 },
        { name = "Crazed Cabbage Smacker",           npcID = 206514, questID = 82558, zone = "Hallowfall",    x = 65.2, y = 29.3 },
        { name = "Croakit",                          npcID = 214757, questID = 82560, zone = "Hallowfall",    x = 67.3, y = 23.4 },
        { name = "Deathpetal",                       npcID = 206184, questID = 82559, zone = "Hallowfall",    x = 63.2, y = 31.4 },
        { name = "Deathtide",                        npcID = 221753, questID = 81880, zone = "Hallowfall",    x = 44.7, y = 42.3 },
        { name = "Duskshadow",                       npcID = 221179, questID = 82562, zone = "Hallowfall",    x = 63.8, y = 19.8 },
        { name = "Finclaw Bloodtide",                npcID = 220492, questID = 82564, zone = "Hallowfall",    x = 61.9, y = 17.2 },
        { name = "Funglour",                         npcID = 221767, questID = 81881, zone = "Hallowfall",    x = 36.8, y = 71.1 },
        { name = "Horror of the Shallows",           npcID = 221668, questID = 81836, zone = "Hallowfall",    x = 43.1, y = 9.7 },
        { name = "Lytfang the Lost",                 npcID = 221534, questID = 81756, zone = "Hallowfall",    x = 23,   y = 59.1 },
        { name = "Moth'ethk",                        npcID = 206203, questID = 82557, zone = "Hallowfall",    x = 63.5, y = 28.8 },
        { name = "Murkspike",                        npcID = 220771, questID = 82565, zone = "Hallowfall",    x = 62.1, y = 12.7 },
        { name = "Parasidious",                      npcID = 206977, questID = 82563, zone = "Hallowfall",    x = 61.6, y = 32.7 },
        { name = "Pride of Beledar",                 npcID = 221786, questID = 81882, zone = "Hallowfall",    x = 57.3, y = 48.6 },
        { name = "Ravageant",                        npcID = 207826, questID = 82566, zone = "Hallowfall",    x = 61.9, y = 32.1 },
        { name = "Sir Alastair Purefire",            npcID = 221708, questID = 81853, zone = "Hallowfall",    x = 36,   y = 35.4 },
        { name = "Sloshmuck",                        npcID = 215805, questID = 79271, zone = "Hallowfall",    x = 73.3, y = 52.6 },
        { name = "Strength of Beledar",              npcID = 221690, questID = 81849, zone = "Hallowfall",    x = 43.6, y = 29.7 },
        { name = "The Perchfather",                  npcID = 221648, questID = 81791, zone = "Hallowfall",    x = 44,   y = 16.3 },
        { name = "The Taskmaker",                    npcID = 218444, questID = 80009, zone = "Hallowfall",    x = 56.4, y = 68.9 },
        { name = "Toadstomper",                      npcID = 207803, questID = 82561, zone = "Hallowfall",    x = 66.6, y = 24 },

        -- Isle of Dorn
        { name = "Clawbreaker K'zithix",             npcID = 221128, questID = 81920, zone = "Isle of Dorn",  x = 55.8, y = 27.6 },
        { name = "Escaped Cutthroat",                npcID = 219266, questID = 81907, zone = "Isle of Dorn",  x = 25.6, y = 45.4 },
        { name = "Flamekeeper Graz",                 npcID = 219279, questID = 81905, zone = "Isle of Dorn",  x = 64,   y = 40.6 },
        { name = "Gar'loc",                          npcID = 219268, questID = 81899, zone = "Isle of Dorn",  x = 53.2, y = 80.4 },
        { name = "Kereke",                           npcID = 222378, questID = 82204, zone = "Isle of Dorn",  x = 30.8, y = 52.3 },
        { name = "Kronolith, Might of the Mountain", npcID = 219270, questID = 81902, zone = "Isle of Dorn",  x = 48.2, y = 26.8 },
        { name = "Matriarch Charfuria",              npcID = 220890, questID = 81921, zone = "Isle of Dorn",  x = 72.8, y = 40.4 },
        { name = "Plaguehart",                       npcID = 219267, questID = 81897, zone = "Isle of Dorn",  x = 50.8, y = 69.9 },
        { name = "Rotfist",                          npcID = 222380, questID = 82205, zone = "Isle of Dorn",  x = 30.8, y = 52.3 },
        { name = "Shallowshell the Clacker",         npcID = 219278, questID = 81903, zone = "Isle of Dorn",  x = 74.4, y = 27.6 },
        { name = "Sweetspark the Oozeful",           npcID = 220883, questID = 81922, zone = "Isle of Dorn",  x = 69.6, y = 38.3 },
        { name = "Tempest Lord Incarnus",            npcID = 219269, questID = 81901, zone = "Isle of Dorn",  x = 57.6, y = 16.4 },
        { name = "Tephratennae",                     npcID = 221126, questID = 81923, zone = "Isle of Dorn",  x = 72.6, y = 40 },
        { name = "Twice-Stinger the Wretched",       npcID = 219271, questID = 81904, zone = "Isle of Dorn",  x = 57,   y = 22.6 },

        -- Ringing Deeps
        { name = "Automaxor",                        npcID = 220265, questID = 81674, zone = "Ringing Deeps", x = 52.6, y = 19.9 },
        { name = "Charmonger",                       npcID = 220267, questID = 81562, zone = "Ringing Deeps", x = 41.4, y = 16.9 },
        { name = "Coalesced Monstrosity",            npcID = 220266, questID = 81511, zone = "Ringing Deeps", x = 57.9, y = 38.1 },
        { name = "Cragmund",                         npcID = 220269, questID = 80560, zone = "Ringing Deeps", x = 50.9, y = 46.3 },
        { name = "Deepflayer Broodmother",           npcID = 220286, questID = 80536, zone = "Ringing Deeps", x = 53,   y = 9.9 },
        { name = "Disturbed Earthgorger",            npcID = 218393, questID = 80003, zone = "Ringing Deeps", x = 67,   y = 52.6 },
        { name = "Hungerer of the Deeps",            npcID = 221199, questID = 81648, zone = "Ringing Deeps", x = 65.8, y = 49.1 },
        { name = "Kelpmire",                         npcID = 220287, questID = 81485, zone = "Ringing Deeps", x = 47,   y = 47 },
        { name = "Lurker of the Deeps",              npcID = 220285, questID = 81633, zone = "Ringing Deeps", x = 60.8, y = 76.6 },
        { name = "Spore-infused Shalewing",          npcID = 221217, questID = 81652, zone = "Ringing Deeps", x = 65.7, y = 47.4 },
        { name = "Terror of the Forge",              npcID = 220271, questID = 80507, zone = "Ringing Deeps", x = 47.4, y = 12.5 },
        { name = "Trungal",                          npcID = 220268, questID = 80574, zone = "Ringing Deeps", x = 72.8, y = 44.3 },
        { name = "Zilthara",                         npcID = 220270, questID = 80506, zone = "Ringing Deeps", x = 52,   y = 26.3 },

        -- Undermine
        { name = "Scrapbeak",                        npcID = 230931, questID = 84917, zone = "Undermine",     x = 69.8, y = 81.4 },
        { name = "Tally Doublespeak",                npcID = 230940, questID = 84919, zone = "Undermine",     x = 37.8, y = 44.2 },
        { name = "Ratspit",                          npcID = 230934, questID = 84918, zone = "Undermine",     x = 25.6, y = 36 },
        { name = "V.V. Goosworth & Slimesby",        npcID = 230946, questID = 84920, zone = "Undermine",     x = 38.4, y = 76.8 },
        { name = "S.A.L.",                           npcID = 230979, questID = 84922, zone = "Undermine",     x = 41.2, y = 25.4 },
        { name = "Candy Stickemup",                  npcID = 231012, questID = 84927, zone = "Undermine",     x = 42.2, y = 77 },
        { name = "Swigs Farsight",                   npcID = 231288, questID = 85004, zone = "Undermine",     x = 41.6, y = 43.8 },
        { name = "The Junk-Wall",                    npcID = 230793, questID = 84884, zone = "Undermine",     x = 64,   y = 48.2 },
        { name = "Chief Foreman Gutso",              npcID = 230828, questID = 84907, zone = "Undermine",     x = 60.6, y = 83.2 },
        { name = "M.A.G.N.O.",                       npcID = 234480, questID = 90488, zone = "Undermine",     x = 40,   y = 22.6 },

        -- K'aresh
        { name = "Ixthar the Unblinking",            npcID = 232128, questID = 90685, zone = "K'aresh",       x = 63.8, y = 44.3, phaseDivingRequired = true },
        { name = "Korgorath the Ravager",            npcID = 232077, questID = 90675, zone = "K'aresh",       x = 66.0, y = 43.5, phaseDivingRequired = true },
        { name = "Maw of the Sands",                 npcID = 231981, questID = 90683, zone = "K'aresh",       x = 54.4, y = 54.4, phaseDivingRequired = true },
        { name = "Morgil the Netherspawn",           npcID = 232108, questID = 90677, zone = "K'aresh",       x = 55.7, y = 52.1, phaseDivingRequired = true },
        { name = "Orith the Dreadful",               npcID = 232127, questID = 90684, zone = "K'aresh",       x = 52.7, y = 20.5, phaseDivingRequired = true },
        { name = "Prototype Mk-V",                   npcID = 232182, questID = 90679, zone = "K'aresh",       x = 46.0, y = 24.2, phaseDivingRequired = true },
        { name = "Revenant of the Wasteland",        npcID = 232189, questID = 90680, zone = "K'aresh",       x = 50.4, y = 64.4, phaseDivingRequired = true },
        { name = "Sha'ryth the Cursed",              npcID = 232006, questID = 90673, zone = "K'aresh",       x = 73.5, y = 55.1, phaseDivingRequired = true },
        { name = "Shadowhowl",                       npcID = 232129, questID = 90674, zone = "K'aresh",       x = 51.4, y = 49.5, phaseDivingRequired = true },
        { name = "Stalker of the Wastes",            npcID = 232193, questID = 90681, zone = "K'aresh",       x = 76.7, y = 42.2, phaseDivingRequired = true },
        { name = "Sthaarbs",                         npcID = 234845, questID = 91431, zone = "K'aresh",       x = 73.8, y = 32.9, phaseDivingRequired = true },
        { name = "The Nightreaver",                  npcID = 232111, questID = 90678, zone = "K'aresh",       x = 51.8, y = 58.6, phaseDivingRequired = true },
        { name = "Urmag",                            npcID = 232195, questID = 90682, zone = "K'aresh",       x = 70.2, y = 49.9, phaseDivingRequired = true },
        { name = "Xarran the Binder",                npcID = 232199, questID = 90672, zone = "K'aresh",       x = 65.1, y = 49.9, phaseDivingRequired = true },
        { name = "\"Chowdar\"",                      npcID = 232098, questID = 90676, zone = "K'aresh",       x = 77.0, y = 74.9 },
        { name = "Arcana-Monger So'zer",             npcID = 241956, questID = 90697, zone = "K'aresh",       x = 34.7, y = 36.1 },
        { name = "Grubber",                          npcID = 238540, questID = 90699, zone = "K'aresh",       x = 71.1, y = 56.9 },
        { name = "Heka'tamos",                       npcID = 245998, questID = 91276, zone = "K'aresh",       x = 75.4, y = 30.4 },
        { name = "Malek'ta",                         npcID = 245997, questID = 91275, zone = "K'aresh",       x = 53.8, y = 59.2 },
    }
    
    addon.raresDB = addon.raresDB or {}
    for _, v in ipairs(twwRares) do
        v.expansion = "theWarWithin"
        table.insert(addon.raresDB, v)
    end
    
    -- Delves Database
    local twwDelves = {
        { name = "Earthcrawl Mines", delveID = 7787, zone = "Isle of Dorn", x = 38.6, y = 74 },
        { name = "Fungal Folly", delveID = 7779, zone = "Isle of Dorn", x = 52.03, y = 65.77 },
        { name = "Kriegval's Rest", delveID = 7781, zone = "Isle of Dorn", x = 62.19, y = 42.7 },
        { name = "Excavation Site 9", delveID = 8181, zone = "Ringing Deeps", x = 76.25, y = 95.85 },
        { name = "The Dread Pit", delveID = 7788, zone = "Ringing Deeps", x = 74.2, y = 37.3 },
        { name = "The Waterworks", delveID = 7782, zone = "Ringing Deeps", x = 46.42, y = 48.71 },
        { name = "Mycomancer Cavern", delveID = 7780, zone = "Hallowfall", x = 71.3, y = 31.2 },
        { name = "Nightfall Sanctum", delveID = 7785, zone = "Hallowfall", x = 34.32, y = 47.43 },
        { name = "Skittering Breach", delveID = 7789, zone = "Hallowfall", x = 65.48, y = 61.74 },
        { name = "The Sinkhole", delveID = 7783, zone = "Hallowfall", x = 50.6, y = 53.3 },
        { name = "Tak-Rethan Abyss", delveID = 7784, zone = "Azj-Kahet", x = 55, y = 73.92 },
        { name = "The Spiral Weave", delveID = 7790, zone = "Azj-Kahet", x = 45, y = 19 },
        { name = "The Underkeep", delveID = 7786, zone = "Azj-Kahet", x = 51.85, y = 88.3 },
        { name = "Sidestreet Sluice", delveID = 8246, zone = "Undermine", x = 34.95, y = 53.14 },
        { name = "Archival Assault", delveID = 8273, zone = "K'aresh", x = 55.1, y = 48.07 },
    }

    addon.delvesDB = addon.delvesDB or {}
    for _, v in ipairs(twwDelves) do
        table.insert(addon.delvesDB, v)
    end
    
    -- Currencies
    local twwCurrencies = {
        -- General
        { name = "Resonance Crystals", id = 2815, icon = 2967113 },

        -- Hallowfall
        { name = "Mereldar Derby Mark", id = 3055, icon = 6012052 },

        -- Azj-Kahet
        { name = "Kej", id = 3056, icon = 4549280 },
        { name = "Nerub-ar Finery", id = 3093, icon = 6012085 },

        -- Undermine
        { name = "Market Research", id = 3226, icon = 1505953 },

        -- K'aresh
        { name = "Untethered Coin", id = 3303, icon = 133791 },
        { name = "Ethereal Strands", id = 3278, icon = 5931153 },
    }

    addon.currencyDB = addon.currencyDB or {}
    for _, v in ipairs(twwCurrencies) do
        v.expansion = "theWarWithin"
        table.insert(addon.currencyDB, v)
    end
    
    -- Reputations
    local twwReputations = {
        { name = "Council of Dornogal", id = 2590, category = "dornogal", order = 1 },
        { name = "Assembly of the Deeps", id = 2594, category = "deeps", order = 2 },
        { name = "Hallowfall Arathi", id = 2570, category = "hallowfall", order = 3 },
        { name = "Flame's Radiance", id = 2688, category = "hallowfall", order = 3.1 },
        { name = "The Severed Threads", id = 2600, category = "azjkahet", order = 4 },
        { name = "The General", id = 2605, category = "azjkahet", order = 4.1 },
        { name = "The Vizier", id = 2607, category = "azjkahet", order = 4.2 },
        { name = "The Weaver", id = 2601, category = "azjkahet", order = 4.3 },
        { name = "The Cartels of Undermine", id = 2653, category = "undermine", order = 5 },
        { name = "Gallagio Loyalty Rewards Club", id = 2685, category = "undermine", order = 5.1 },
        { name = "Bilgewater Cartel", id = 2673, category = "undermine", order = 5.2 },
        { name = "Blackwater Cartel", id = 2675, category = "undermine", order = 5.3 },
        { name = "Darkfuse Solutions", id = 2669, category = "undermine", order = 5.4 },
        { name = "Steamwheedle Cartel", id = 2677, category = "undermine", order = 5.5 },
        { name = "Venture Company", id = 2671, category = "undermine", order = 5.6 },
        { name = "The K'aresh Trust", id = 2658, category = "karesh", order = 6 },
        { name = "Manaforge Vandals", id = 2736, category = "karesh", order = 6.1 },
        { name = "Brann Bronzebeard", id = 2640, category = "delves", order = 99 },
    }

    addon.reputationDB = addon.reputationDB or {}
    for _, v in ipairs(twwReputations) do
        v.expansion = "theWarWithin"
        table.insert(addon.reputationDB, v)
    end

    -- Reputation grouping
    addon.reputationParentMap = addon.reputationParentMap or {}
    addon.reputationParentMap[2600] = {2605, 2607, 2601} -- The Severed Threads -> The General, The Vizier, The Weaver
    addon.reputationParentMap[2653] = {2673, 2675, 2677, 2671, 2669} -- The Cartels of Undermine -> Bilgewater, Blackwater, Darkfuse, Steamwheedle, Venture Company

    addon.reputationSortOrder = addon.reputationSortOrder or {}
    for _, v in ipairs(twwReputations) do
        if v.order then addon.reputationSortOrder[v.id] = v.order end
    end
    

end)
