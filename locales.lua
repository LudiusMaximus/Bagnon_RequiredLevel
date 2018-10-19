local MODULE, moduleData =  ...


-- Check these items to create more locales...
-- Outland:   https://www.wowhead.com/item=34126/recipe-shoveltusk-soup
-- Northrend: https://www.wowhead.com/item=43036/recipe-dragonfin-filet
-- Cataclysm: https://www.wowhead.com/item=62800/recipe-seafood-magnifique-feast
-- Pandaria:  https://www.wowhead.com/item=74658/recipe-spicy-vegetable-chips
-- Draenor:   https://www.wowhead.com/item=116347/recipe-burnished-leather-bag
-- Legion:    https://www.wowhead.com/item=133830/recipe-lavish-suramar-feast
-- Zandalari: https://www.wowhead.com/spell=265817/zandalari-cooking
-- Kul Tiran: https://www.wowhead.com/spell=264646/kul-tiran-cooking


-- The %s in _G.ITEM_MIN_SKILL = "Requires %s (%d)" is replaced
-- by an expansion identifier and the profession name.
-- But the order depends on the locale.
-- e: expansion identifier
-- p: profession name
moduleData.itemMinSkillString = {
  ["enUS"] = "e p",
  ["enGB"] = "e p",
  ["deDE"] = "p e",
  ["frFR"] = "p e",
  ["itIT"] = "p e",
}

moduleData.expansionIdentifierToVersionNumber = {
  ["enUS"] = {
    [""] =                      "1",
    ["Outland"] =               "2",
    ["Northrend"] =             "3",
    ["Cataclysm"] =             "4",
    ["Pandaria"] =              "5",
    ["Draenor"] =               "6",
    ["Legion"] =                "7",
    ["Zandalari"] =             "8",
    ["Kul Tiran"] =             "8",
  },
  ["enGB"] = {
    [""] =                      "1",
    ["Outland"] =               "2",
    ["Northrend"] =             "3",
    ["Cataclysm"] =             "4",
    ["Pandaria"] =              "5",
    ["Draenor"] =               "6",
    ["Legion"] =                "7",
    ["Zandalari"] =             "8",
    ["Kul Tiran"] =             "8",
  },
  ["deDE"] = {
    [""] =                      "1",
    ["der Scherbenwelt"] =      "2",
    ["von Nordend"] =           "3",
    ["des Kataklysmus"] =       "4",
    ["von Pandaria"] =          "5",
    ["von Draenor"] =           "6",
    ["der Verheerten Inseln"] = "7",
    ["von Zandalar"] =          "8",
    ["von Kul Tiras"] =         "8",
  },
  ["frFR"] = {
    [""] =                      "1",
    ["de l’Outreterre"] =       "2",
    ["du Norfendre"] =          "3",
    ["de Cataclysm"] =          "4",
    ["de Pandarie"] =           "5",
    ["de Draenor"] =            "6",
    ["de Legion"] =             "7",
    ["de Zandalar"] =           "8",
    ["de Kul Tiras"] =          "8",
  },
  ["itIT"] = {
    [""] =                      "1",
    ["delle Terre Esterne"] =   "2",
    ["di Nordania"] =           "3",
    ["di Cataclysm"] =          "4",
    ["di Pandaria"] =           "5",
    ["di Draenor"] =            "6",
    ["di Legion"] =             "7",
    ["di Zandalar"] =           "8",
    ["di Kul Tiras"] =          "8",
  },
}