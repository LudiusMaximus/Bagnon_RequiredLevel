-- Using the Bagnon way to retrieve names, namespaces and stuff
local MODULE, moduleData =  ...
local ADDON, Addon = MODULE:match("[^_]+"), _G[MODULE:match("[^_]+")]
local Module = Bagnon:NewModule("RequiredLevel", Addon)

local Unfit = LibStub('Unfit-1.0')

-- Lua API
local _G = _G
local select = select
local string_find = string.find
local string_gsub = string.gsub
local string_match = string.match
local tonumber = tonumber

-- WoW API
local CreateFrame = _G.CreateFrame
local GetDetailedItemLevelInfo = _G.GetDetailedItemLevelInfo
local GetItemInfo = _G.GetItemInfo
local GetItemQualityColor = _G.GetItemQualityColor

-- Cache of RequiredLevel texts
local ButtonCache = {}

-- Initialize the button
local CacheButton = function(self)

  -- Adding an extra layer to get it above glow and border textures
  local PluginContainerFrame = _G[self:GetName().."RequiredLevelFrame"] or CreateFrame("Frame", self:GetName().."RequiredLevelFrame", self)
  PluginContainerFrame:SetAllPoints()

  -- Using standard blizzard fonts here
  local RequiredLevel = PluginContainerFrame:CreateFontString()
  RequiredLevel:SetDrawLayer("ARTWORK", 1)
  RequiredLevel:SetPoint("BOTTOMLEFT", 2, 2)
  RequiredLevel:SetTextColor(.95, .95, .95)

  -- Store the reference for the next time
  ButtonCache[self] = RequiredLevel

  return RequiredLevel
end


-- Tooltip used for scanning.
local scannerTooltip = CreateFrame("GameTooltip", "BagnonRequiredLevelScannerTooltip", nil, "GameTooltipTemplate")

-- Function to set the tooltip to the current item.
local SetTooltip = function(self)
  scannerTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
  scannerTooltip:SetBagItem(self:GetBag(), self:GetID())
  if (scannerTooltip:NumLines() == 0) then
    scannerTooltip:SetHyperlink(self:GetItem())
  end
end



local ItemNeedsLockpicking = function(self)

  SetTooltip(self)

  -- Get the localised name for Lockpicking.
  local localisedLockpicking = GetSpellInfo(1809)

  -- https://www.lua.org/pil/20.2.html
  -- "%s?%%.-s%s" matches both " %s " (EN), "%s " (FR) and " %1$s " (DE) in _G.ITEM_MIN_SKILL.
  -- "%(%%.-d%)%s?" matches both "(%d)" (EN), "(%d) " (FR) and "(%2$d)" (DE) in _G.ITEM_MIN_SKILL.
  searchPattern = string_gsub(string_gsub("^" .. _G.ITEM_MIN_SKILL .. "$", "%s?%%.-s%s", ".-" .. localisedLockpicking .. ".-%%s"), "%(%%.-d%)%s?", "%%((%%d+)%%)%%s?")

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
local CharacterHasProfession = function(self)

  local _, _, _, _, _, _, itemSubType, _, _, _, _, _, itemSubTypeId = GetItemInfo(self:GetItem())

  if (itemSubTypeId == LE_ITEM_RECIPE_BOOK) then

    SetTooltip(self)

    -- Cannot do "for .. in ipairs", because if one profession is missing,
    -- the iteration would stop...
    local professionList = {}
    professionList[1], professionList[2], professionList[3], professionList[4], professionList[5] = GetProfessions()
    for i = 1, 5 do
      if (professionList[i]) then

        local professionName = GetProfessionInfo(professionList[i])

        -- https://www.lua.org/pil/20.2.html
        -- "%s?%%.-s%s" matches both " %s " (EN), "%s " (FR) and " %1$s " (DE) in _G.ITEM_MIN_SKILL.
        -- "%(%%.-d%)%s?" matches both "(%d)" (EN), "(%d) " (FR) and "(%2$d)" (DE) in _G.ITEM_MIN_SKILL.
        searchPattern = string_gsub(string_gsub("^" .. _G.ITEM_MIN_SKILL .. "$", "%s?%%.-s%s", ".-" .. professionName .. ".-%%s"), "%(%%.-d%)%s?", ".-")

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
--          self            : The current item button; needed to set tooltip.
-- Output:  alreadyKnown    : True if recipe is already known.
--          notEnoughSkill  : True if character does not have enough profession skill.
--          expansionPrefix : Prefix depending on the recipe's WoW expansion.
--          requiredSkill   : Required profession skill to learn recipe.
local ReadRecipeTooltip = function(professionName, self)

  SetTooltip(self)

  -- https://www.lua.org/pil/20.2.html
  local searchPattern = nil
  local searchOnlySkillPattern = nil

  -- If the locale is not known, just search for the required skill and ignore the expansion.
  if not moduleData.itemMinSkillString[GetLocale()] or not moduleData.expansionIdentifierToVersionNumber[GetLocale()] then
    searchOnlySkillPattern = "^.*%((%d+)%).*$"
  else
    -- _G.ITEM_MIN_SKILL = "Requires %s (%d)"
    -- ...must be turned into: "^Requires%s(.*)%s?" .. localisedItemMinSkill .. "%s%((%d+)%)$"
    -- But watch out: For different locales the order of words is different (see below)!

    -- Need %%%%s here, because this string will be inserted twice.
    local localisedItemMinSkill = string_gsub(string_gsub(string_gsub(moduleData.itemMinSkillString[GetLocale()], " ", "%%%%s?"), "e", "(.*)"), "p", professionName)

    -- "%s?%%.-s%s" matches both " %s " (EN), "%s " (FR) and " %1$s " (DE) in _G.ITEM_MIN_SKILL.
    -- "%(%%.-d%)%s?" matches both "(%d)" (EN), "(%d) " (FR) and "(%2$d)" (DE) in _G.ITEM_MIN_SKILL.
    searchPattern = string_gsub(string_gsub("^" .. _G.ITEM_MIN_SKILL .. "$", "%s?%%.-s%s", "%%s?" .. localisedItemMinSkill .. "%%s"), "%(%%.-d%)%s?", "%%((%%d+)%%)%%s?")
  end

  -- Tooltip and scanning by Phanx (https://www.wowinterface.com/forums/showthread.php?p=270331#post270331)
  for i = scannerTooltip:NumLines(), 2, -1 do
    local line = _G[scannerTooltip:GetName().."TextLeft"..i]
    if line then
      local msg = line:GetText()
      if msg then

        if (msg == _G.ITEM_SPELL_KNOWN) then
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



local PostUpdateButton = function(self)
  local itemLink = self:GetItem()
  if itemLink then

    -- Locked items should always be greyed out.
    if self.info.locked then
      _G[self:GetName().."IconTexture"]:SetVertexColor(1,1,1)
      _G[self:GetName().."IconTexture"]:SetDesaturated(1)
    end

    -- Retrieve or create this button's RequiredLevel text.
    local RequiredLevel = ButtonCache[self] or CacheButton(self)
    -- Got to set a default font.
    RequiredLevel:SetFont("Fonts\\ARIALN.TTF", 14, "OUTLINE")

    -- Get some blizzard info about the current item.
    local _, _, _, _, itemMinLevel, _, itemSubType, _, _, _, _, itemTypeId, itemSubTypeId = GetItemInfo(itemLink)


    -- Check for Junkboxes and Lockboxes (Miscellaneous Junk).
    if ((itemTypeId == 15) and (itemSubTypeId == 0)) then
      local itemNeedsLockpicking, notEnoughSkill, requiredSkill = ItemNeedsLockpicking(self)

      if (itemNeedsLockpicking) then
        if notEnoughSkill then
          RequiredLevel:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
          RequiredLevel:SetText(requiredSkill)

          if not self.info.locked then
            _G[self:GetName().."IconTexture"]:SetVertexColor(1,.3,.3)
            _G[self:GetName().."IconTexture"]:SetDesaturated(1)
          end
          return
        end
      end
    end


    if (itemMinLevel) then
      if (itemMinLevel > UnitLevel("player")) then

        if not Unfit:IsItemUnusable(itemLink) then
          RequiredLevel:SetText(itemMinLevel)
          if not self.info.locked then
            _G[self:GetName().."IconTexture"]:SetVertexColor(1,.3,.3)
            _G[self:GetName().."IconTexture"]:SetDesaturated(1)
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
      local hasProfession, professionName = CharacterHasProfession(self)

      if not hasProfession then
        RequiredLevel:SetText("")
        if Addon.sets.glowUnusable then
          r, g, b = RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b
          self.IconBorder:SetTexture(id and C_ArtifactUI.GetRelicInfoByItemID(id) and 'Interface\\Artifacts\\RelicIconFrame' or 'Interface\\Common\\WhiteIconFrame')
          self.IconBorder:SetVertexColor(r, g, b)
          self.IconBorder:SetShown(r)
          self.IconGlow:SetVertexColor(r, g, b, Addon.sets.glowAlpha)
          self.IconGlow:SetShown(r)
        end
        return
      end

      -- Scan tooltip. (Not checking for itemSubTypeId != LE_ITEM_RECIPE_BOOK here because of efficiency.)
      local alreadyKnown, notEnoughSkill, expansionPrefix, requiredSkill = ReadRecipeTooltip(professionName, self)

      if alreadyKnown then
        RequiredLevel:SetText("")
        if not self.info.locked then
          _G[self:GetName().."IconTexture"]:SetVertexColor(.4,.9,.4)
          _G[self:GetName().."IconTexture"]:SetDesaturated(1)
        end
        return
      end

      if notEnoughSkill then
        RequiredLevel:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
        RequiredLevel:SetText(expansionPrefix .. requiredSkill)

        if not self.info.locked then
          _G[self:GetName().."IconTexture"]:SetVertexColor(1,.3,.3)
          _G[self:GetName().."IconTexture"]:SetDesaturated(1)
        end
        return
      end

      -- Recipe is actually learnable.
      RequiredLevel:SetText("")
      if not self.info.locked then
        _G[self:GetName().."IconTexture"]:SetVertexColor(1,1,1)
        _G[self:GetName().."IconTexture"]:SetDesaturated(nil)
      end
      return
    end

    -- Any other item.
    RequiredLevel:SetText("")
    if not self.info.locked then
      _G[self:GetName().."IconTexture"]:SetVertexColor(1,1,1)
      _G[self:GetName().."IconTexture"]:SetDesaturated(nil)
    end

  else
    if ButtonCache[self] then
      ButtonCache[self]:SetText("")
    end
  end
end



Module.OnEnable = function(self)
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
