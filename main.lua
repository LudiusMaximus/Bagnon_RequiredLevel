-- Using the Bagnon way to retrieve names, namespaces and stuff
local MODULE, moduleData =  ...
local ADDON, Addon = MODULE:match("[^_]+"), _G[MODULE:match("[^_]+")]
local Module = Bagnon:NewModule("RequiredLevel", Addon)

local Unfit = LibStub('Unfit-1.0')

-- Lua API
local _G = _G
local string_find = string.find
local string_gsub = string.gsub
local string_match = string.match
local tonumber = tonumber

-- WoW API
local CreateFrame = _G.CreateFrame
local GetItemInfo = _G.GetItemInfo
local GetSpellInfo = _G.GetSpellInfo
local GetProfessions = _G.GetProfessions
local GetProfessionInfo = _G.GetProfessionInfo
local UnitLevel = _G.UnitLevel

-- WoW Strings
local ITEM_MIN_SKILL = _G.ITEM_MIN_SKILL
local ITEM_SPELL_KNOWN = _G.ITEM_SPELL_KNOWN
local LE_ITEM_CLASS_RECIPE = _G.LE_ITEM_CLASS_RECIPE
local LE_ITEM_RECIPE_BOOK = _G.LE_ITEM_RECIPE_BOOK


-- Cache of RequiredLevel texts
local ButtonCache = {}



-- Retrieve a button's plugin container
local GetPluginContainter = function(button)
	local name = button:GetName() .. "RequiredLevelFrame"
	local frame = _G[name]
	if (not frame) then 
    -- Adding an extra layer to get it above glow and border textures.
		frame = CreateFrame("Frame", name, button)
		frame:SetAllPoints()
	end 
	return frame
end

-- Initialize the button
local CacheButton = function(button)

  -- Using standard blizzard fonts here
  local RequiredLevel = GetPluginContainter(button):CreateFontString()
  RequiredLevel:SetDrawLayer("ARTWORK", 1)
  RequiredLevel:SetPoint("BOTTOMLEFT", 2, 2)
  RequiredLevel:SetTextColor(.95, .95, .95)


  -- Hide Goldpaw's frame.
  -- TODO: Would be nicer to just replace the "BoE" text in bottomLeft corner...
  -- local GoldpawFrame = _G[button:GetName().."ExtraInfoFrame"]
  -- if GoldpawFrame and GoldpawFrame:IsVisible() then
    -- GoldpawFrame:Hide()
  -- end
  
  -- Move Pawn out of the way.
  local UpgradeIcon = button.UpgradeIcon
  if UpgradeIcon then
    UpgradeIcon:ClearAllPoints()
    UpgradeIcon:SetPoint("BOTTOMRIGHT", 2, 0)
  end

  -- Store the reference for the next time.
  ButtonCache[button] = RequiredLevel

  return RequiredLevel
end


-- Tooltip used for scanning.
local scannerTooltip = CreateFrame("GameTooltip", "BagnonRequiredLevelScannerTooltip", nil, "GameTooltipTemplate")
scannerTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")


-- Function to set the tooltip to the current item.
local SetTooltip = function(button)

  -- Clear the tooltip.
  scannerTooltip:ClearLines()

  -- SetBagItem() does not work for bank slots. So we use this instead.
  -- (Thanks to p3lim: https://www.wowinterface.com/forums/showthread.php?p=331883)
  if (button:GetBag() == -1) then
    scannerTooltip:SetInventoryItem('player', button:GetID()+47)
  else
    -- Try to set the tooltip with button:GetBag() and button:GetID().
    scannerTooltip:SetBagItem(button:GetBag(), button:GetID())
  end

  -- The above will still fail for cached bags; like bank slots while not
  -- at the bank or bags of other characters. In this case we use the
  -- SetHyperlink() fallback, which may sometimes be inaccurate.
  if (scannerTooltip:NumLines() == 0) then
    scannerTooltip:SetHyperlink(button:GetItem())
  end

end



local ItemNeedsLockpicking = function(button)

  SetTooltip(button)

  -- Get the localised name for Lockpicking.
  local localisedLockpicking = GetSpellInfo(1809)

  -- https://www.lua.org/pil/20.2.html
  -- "%s?%%.-s%s" matches both " %s " (EN), "%s " (FR) and " %1$s " (DE) in ITEM_MIN_SKILL.
  -- "%(%%.-d%)%s?" matches both "(%d)" (EN), "(%d) " (FR) and "(%2$d)" (DE) in ITEM_MIN_SKILL.
  searchPattern = string_gsub(string_gsub("^" .. ITEM_MIN_SKILL .. "$", "%s?%%.-s%s", ".-" .. localisedLockpicking .. ".-%%s"), "%(%%.-d%)%s?", "%%((%%d+)%%)%%s?")

  -- Tooltip and scanning by Phanx (https://www.wowinterface.com/forums/showthread.php?p=270331#post270331)
  for i = scannerTooltip:NumLines(), 2, -1 do
    local line = _G[scannerTooltip:GetName().."TextLeft"..i]
    if line then
      local msg = line:GetText()
      if msg then
        if (string_find(msg, searchPattern)) then
          local requiredSkill = string_match(msg, searchPattern)
          local _, g = line:GetTextColor()
          return true, (tonumber(g) < 0.2), requiredSkill
        end
      end
    end
  end

end



-- Function to return if the character has a certain profession.
-- For "Book" recipes we have to scan the tooltip
-- in order to extract and return the profession name.
local CharacterHasProfession = function(button)

  local _, _, _, _, _, _, itemSubType, _, _, _, _, _, itemSubTypeId = GetItemInfo(button:GetItem())

  if (itemSubTypeId == LE_ITEM_RECIPE_BOOK) then
  
    SetTooltip(button)

    -- Cannot do "for .. in ipairs", because if one profession is missing,
    -- the iteration would stop...
    local professionList = {}
    professionList[1], professionList[2], professionList[3], professionList[4], professionList[5] = GetProfessions()
    for i = 1, 5 do
      if (professionList[i]) then

        local professionName = GetProfessionInfo(professionList[i])

        -- https://www.lua.org/pil/20.2.html
        -- "%s?%%.-s%s" matches both " %s " (EN), "%s " (FR) and " %1$s " (DE) in ITEM_MIN_SKILL.
        -- "%(%%.-d%)%s?" matches both "(%d)" (EN), "(%d) " (FR) and "(%2$d)" (DE) in ITEM_MIN_SKILL.
        searchPattern = string_gsub(string_gsub("^" .. ITEM_MIN_SKILL .. "$", "%s?%%.-s%s", ".-" .. professionName .. ".-%%s"), "%(%%.-d%)%s?", ".-")

        -- Tooltip and scanning by Phanx (https://www.wowinterface.com/forums/showthread.php?p=270331#post270331)
        for i = scannerTooltip:NumLines(), 2, -1 do
          local line = _G[scannerTooltip:GetName().."TextLeft"..i]
          if line then
            local msg = line:GetText()
            if msg then
              if (string_find(msg, searchPattern)) then
                return true, professionName
              end
            end
          end
        end

      end
    end

    return false, nil

  -- For all other recipes, itemSubType is also the profession name.
  else
    -- Cannot do "for .. in ipairs", because if one profession is missing,
    -- the iteration would stop...
    local professionList = {}
    professionList[1], professionList[2], professionList[3], professionList[4], professionList[5] = GetProfessions()
    for i = 1, 5 do
      if (professionList[i]) then
        if (itemSubType == GetProfessionInfo(professionList[i])) then
          return true, itemSubType
        end
      end
    end

    return false, nil
  end

end



-- expansionPrefixes:
-- Define here what should be printed before the skill level of recipes.
moduleData.EP_VANILLA =  "1"
moduleData.EP_BC =       "2"
moduleData.EP_WRATH =    "3"
moduleData.EP_CATA =     "4"
moduleData.EP_PANDARIA = "5"
moduleData.EP_WOD =      "6"
moduleData.EP_LEGION =   "7"
moduleData.EP_BFA =      "8"



-- Input:   professionName  : The localised profession name to search for.
--          button          : The current item button; needed to set tooltip.
-- Output:  alreadyKnown    : True if recipe is already known.
--          notEnoughSkill  : True if character does not have enough profession skill.
--          expansionPrefix : Prefix depending on the recipe's WoW expansion.
--          requiredSkill   : Required profession skill to learn recipe.
local ReadRecipeTooltip = function(professionName, button)

  SetTooltip(button)

  -- https://www.lua.org/pil/20.2.html
  local searchPattern = nil
  local searchOnlySkillPattern = nil

  -- If the locale is not known, just search for the required skill and ignore the expansion.
  if not moduleData.itemMinSkillString[GetLocale()] or not moduleData.expansionIdentifierToVersionNumber[GetLocale()] then
    searchOnlySkillPattern = "^.*%((%d+)%).*$"
  else
    -- ITEM_MIN_SKILL = "Requires %s (%d)"
    -- ...must be turned into: "^Requires%s(.*)%s?" .. localisedItemMinSkill .. "%s%((%d+)%)$"
    -- But watch out: For different locales the order of words is different (see below)!

    -- Need %%%%s here, because this string will be inserted twice.
    local localisedItemMinSkill = string_gsub(string_gsub(string_gsub(moduleData.itemMinSkillString[GetLocale()], " ", "%%%%s?"), "e", "(.*)"), "p", professionName)

    -- "%s?%%.-s%s" matches both " %s " (EN), "%s " (FR) and " %1$s " (DE) in ITEM_MIN_SKILL.
    -- "%(%%.-d%)%s?" matches both "(%d)" (EN), "(%d) " (FR) and "(%2$d)" (DE) in ITEM_MIN_SKILL.
    searchPattern = string_gsub(string_gsub("^" .. ITEM_MIN_SKILL .. "$", "%s?%%.-s%s", "%%s?" .. localisedItemMinSkill .. "%%s"), "%(%%.-d%)%s?", "%%((%%d+)%%)%%s?")
  end

  -- Tooltip and scanning by Phanx (https://www.wowinterface.com/forums/showthread.php?p=270331#post270331)
  for i = scannerTooltip:NumLines(), 2, -1 do
    local line = _G[scannerTooltip:GetName().."TextLeft"..i]
    if line then
      local msg = line:GetText()
      if msg then

        if (msg == ITEM_SPELL_KNOWN) then
          -- If the recipe is already known, we are not interested in its required skill level!
          return true, nil, nil, nil

        elseif searchPattern and string_find(msg, searchPattern) then

          local expansionIdentifier, requiredSkill = string_match(msg, searchPattern)
          -- Trim trailing blank space if any.
          expansionIdentifier = string_gsub(expansionIdentifier, "^(.-)%s$", "%1")

          -- Check if recipe can be learned, i.e. text is not red.
          local _, g = line:GetTextColor()

          -- Check if the expansionIdentifier is actually known.
          local expansionPrefix = moduleData.expansionIdentifierToVersionNumber[GetLocale()][expansionIdentifier]
          if not expansionPrefix then
            print ("Bagnon_RequiredLevel (ERROR): Could not find", expansionIdentifier, "for", GetLocale())
            expansionPrefix = "?"
          end

          return false, (tonumber(g) < 0.2), expansionPrefix .. ".", requiredSkill

        elseif searchOnlySkillPattern and string_find(msg, searchOnlySkillPattern) then
          local requiredSkill = string_match(msg, searchOnlySkillPattern)
          -- Check if recipe can be learned, i.e. text is not red.
          local _, g = line:GetTextColor()
          return false, (tonumber(g) < 0.2), "", requiredSkill
        end
      end
    end
  end

  -- We may actually reach here if a non-recipe item swaps slots with a recipe item.
  return nil, nil, nil, nil

end



local PostUpdateButton = function(button)
  local itemLink = button:GetItem()
  if itemLink then

    -- Locked items should always be greyed out.
    if button.info.locked then
      local buttonIconTexture = _G[button:GetName().."IconTexture"]
      buttonIconTexture:SetVertexColor(1,1,1)
      buttonIconTexture:SetDesaturated(1)
    end

    -- Retrieve or create this button's RequiredLevel text.
    local RequiredLevel = ButtonCache[button] or CacheButton(button)
    -- Got to set a default font.
    RequiredLevel:SetFont("Fonts\\ARIALN.TTF", 14, "OUTLINE")

    -- Get some blizzard info about the current item.
    local _, _, _, _, itemMinLevel, _, itemSubType, _, _, _, _, itemTypeId, itemSubTypeId = GetItemInfo(itemLink)


    -- Check for Junkboxes and Lockboxes (Miscellaneous Junk).
    if ((itemTypeId == 15) and (itemSubTypeId == 0)) then
      local itemNeedsLockpicking, notEnoughSkill, requiredSkill = ItemNeedsLockpicking(button)

      if (itemNeedsLockpicking) then
        if notEnoughSkill then
          RequiredLevel:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
          RequiredLevel:SetText(requiredSkill)

          if not button.info.locked then
            local buttonIconTexture = _G[button:GetName().."IconTexture"]
            buttonIconTexture:SetVertexColor(1,.3,.3)
            buttonIconTexture:SetDesaturated(1)
          end
          return
        end
      end
    end


    if (itemMinLevel) then
      if (itemMinLevel > UnitLevel("player")) then

        if not Unfit:IsItemUnusable(itemLink) then
          RequiredLevel:SetText(itemMinLevel)
          if not button.info.locked then
            local buttonIconTexture = _G[button:GetName().."IconTexture"]
            buttonIconTexture:SetVertexColor(1,.3,.3)
            buttonIconTexture:SetDesaturated(1)
          end
        end
        return
      end
    end

    -- LE_ITEM_CLASS_RECIPE by Kanegasi (https://www.wowinterface.com/forums/showthread.php?p=330514#post330514)
    if (itemTypeId == LE_ITEM_CLASS_RECIPE) then
    
      -- For almost all recipes, itemSubType is also the profession name.
      -- https://wow.gamepedia.com/ItemType
      -- However, for "Book" recipes we have to extract the profession name from
      -- the tooltip. We do this at the same time as checking if the player has
      -- the profession at all. Thus, we only have to scan the tooltip for the professions
      -- the player has.
      local hasProfession, professionName = CharacterHasProfession(button)

      if not hasProfession then
        RequiredLevel:SetText("")
        if Addon.sets.glowUnusable then
          r, g, b = RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b
          button.IconBorder:SetTexture(id and C_ArtifactUI.GetRelicInfoByItemID(id) and 'Interface\\Artifacts\\RelicIconFrame' or 'Interface\\Common\\WhiteIconFrame')
          button.IconBorder:SetVertexColor(r, g, b)
          button.IconBorder:SetShown(r)
          button.IconGlow:SetVertexColor(r, g, b, Addon.sets.glowAlpha)
          button.IconGlow:SetShown(r)
        end
        return
      end

      -- Scan tooltip. (Not checking for itemSubTypeId != LE_ITEM_RECIPE_BOOK here because of efficiency.)
      local alreadyKnown, notEnoughSkill, expansionPrefix, requiredSkill = ReadRecipeTooltip(professionName, button)

      if alreadyKnown then
        RequiredLevel:SetText("")
        if not button.info.locked then
          local buttonIconTexture = _G[button:GetName().."IconTexture"]
          buttonIconTexture:SetVertexColor(.4,.4,.4)
          buttonIconTexture:SetDesaturated(1)
        end
        return
      end

      if notEnoughSkill then
      
        RequiredLevel:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
        RequiredLevel:SetText(expansionPrefix .. requiredSkill)

        if not button.info.locked then
          local buttonIconTexture = _G[button:GetName().."IconTexture"]
          buttonIconTexture:SetVertexColor(1,.3,.3)
          buttonIconTexture:SetDesaturated(1)
        end
        return
      end

      -- Recipe is actually learnable.
      RequiredLevel:SetText("")
      if not button.info.locked then
        local buttonIconTexture = _G[button:GetName().."IconTexture"]
        buttonIconTexture:SetVertexColor(1,1,1)
        buttonIconTexture:SetDesaturated(nil)
      end
      return
    end

    -- Any other item.
    RequiredLevel:SetText("")
    if not button.info.locked then
      local buttonIconTexture = _G[button:GetName().."IconTexture"]
      buttonIconTexture:SetVertexColor(1,1,1)
      buttonIconTexture:SetDesaturated(nil)
    end

  else
    if ButtonCache[button] then
      ButtonCache[button]:SetText("")
    end
  end
end



Module.OnEnable = function()
  hooksecurefunc(Bagnon.ItemSlot, "Update", PostUpdateButton)

  -- Needed because otherwise UpdateUpgradeIcon will reset the VertexColor.
  hooksecurefunc(Bagnon.ItemSlot, "UpdateUpgradeIcon", PostUpdateButton)

  -- Needed to set the VertexColor in time when BAG_UPDATE_COOLDOWN is triggered.
  hooksecurefunc(Bagnon.ItemSlot, "UpdateCooldown", PostUpdateButton)

  -- Needed to keep the frame of unusable recipes.
  hooksecurefunc(Bagnon.ItemSlot, "OnEnter", PostUpdateButton)
  hooksecurefunc(Bagnon.ItemSlot, "OnLeave", PostUpdateButton)

  -- Needed to keep the desaturation.
  hooksecurefunc(Bagnon.ItemSlot, "SetLocked", PostUpdateButton)

end
