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
	RequiredLevel:SetPoint("BOTTOMLEFT", 2, 1)
  RequiredLevel:SetTextColor(.95, .95, .95)

	-- Store the reference for the next time
	ButtonCache[self] = RequiredLevel

	return RequiredLevel
end


-- Tooltip used for scanning
local scannerTooltip = CreateFrame("GameTooltip", "BagnonRequiredLevelscannerTooltip", WorldFrame, "GameTooltipTemplate")

-- Function to return if the character has a certain profession.
local CharacterHasProfession = function(professionName)
  for _, professionIndex in ipairs({GetProfessions()}) do
    if (professionName == GetProfessionInfo(professionIndex)) then
      return true;
    end
  end
  return false
end


-- Input:   scannerTooltip  : Tooltip of the recipe.
--          professionName  : Localised itemSubType of the recipe (getItemInfo()).
-- Output:  alreadyKnown    : True if recipe is already known.
--          notEnoughSkill  : True if character does not have enough profession skill.
--          expansionPrefix : Prefix depending on the recipe's WoW expansion.
--          requiredSkill   : Required profession skill to learn recipe.
local ReadRecipeTooltip = function(scannerTooltip, professionName)

  local searchPattern = nil
  local searchOnlySkillPattern = nil

  -- If the locale is not known, just search for the required skill and ignore the expansion.
  if not moduleData.itemMinSkillString[GetLocale()] or not moduleData.expansionIdentifierToVersionNumber[GetLocale()] then
    searchOnlySkillPattern = "^.*%((%d+)%).*$"
  else
    -- _G.ITEM_MIN_SKILL = "Requires %s (%d)"
    -- ...must be turned into: "^Requires%s(.*)%s?" .. itemSubType .. "%s%((%d+)%)$"

    -- Need %%%%s here, because this string will be inserted twice.
    local localisedItemMinSkill = string_gsub(string_gsub(string_gsub(moduleData.itemMinSkillString[GetLocale()], " ", "%%%%s?"), "e", "(.*)"), "p", professionName)

    -- "%s?%%.-s%s" matches both " %s " (EN), "%s " (FR) and " %1$s " (DE) in _G.ITEM_MIN_SKILL.
    -- "%(%%.-d%)%s?" matches both " (%d)" (EN), " (%d) " (FR) and " (%2$d)" (DE) in _G.ITEM_MIN_SKILL.
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

          -- Check if recipe can be learned.
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
          -- Check if recipe can be learned.
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

		-- Retrieve or create this button's RequiredLevel text
		local RequiredLevel = ButtonCache[self] or CacheButton(self)
    -- Got to set a default font.
    RequiredLevel:SetFont("Fonts\\ARIALN.TTF", 14, "OUTLINE")

		-- Get some blizzard info about the current item
		local _, _, _, _, itemMinLevel, _, itemSubType, _, _, _, _, itemTypeId = GetItemInfo(itemLink)

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


    -- LE_ITEM_CLASS_RECIPE by Kanegasi (https://www.wowinterface.com/forums/showthread.php?p=330514#post330514)
    if (itemTypeId == LE_ITEM_CLASS_RECIPE) then

      if not CharacterHasProfession(itemSubType) then
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


      -- print ("---->", itemLink, string.match(itemLink, "item[%-?%d:]+"))

      -- Scan tooltip.
      scannerTooltip.owner = self
      scannerTooltip:SetOwner(self, "ANCHOR_NONE")
      scannerTooltip:SetBagItem(self:GetBag(), self:GetID())
      if (scannerTooltip:NumLines() == 0) then
        scannerTooltip:SetHyperlink(itemLink)
      end

      local alreadyKnown, notEnoughSkill, expansionPrefix, requiredSkill = ReadRecipeTooltip(scannerTooltip, itemSubType)

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

    -- Any other item.
    else
      RequiredLevel:SetText("")
      if not self.info.locked then
        _G[self:GetName().."IconTexture"]:SetVertexColor(1,1,1)
        _G[self:GetName().."IconTexture"]:SetDesaturated(nil)
      end
		end
	else
		if ButtonCache[self] then
			ButtonCache[self]:SetText("")
		end
	end
end

Module.OnEnable = function(self)
	hooksecurefunc(Bagnon.ItemSlot, "Update", PostUpdateButton)

  -- Needed because otherwise, UpdateUpgradeIcon will reset the VertexColor.
	hooksecurefunc(Bagnon.ItemSlot, "UpdateUpgradeIcon", PostUpdateButton)
  -- Needed to set the VertexColor in time when BAG_UPDATE_COOLDOWN is triggered.
	hooksecurefunc(Bagnon.ItemSlot, "UpdateCooldown", PostUpdateButton)
  -- Needed to keep the frame of unusable recipes.
	hooksecurefunc(Bagnon.ItemSlot, "OnEnter", PostUpdateButton)
	hooksecurefunc(Bagnon.ItemSlot, "OnLeave", PostUpdateButton)
  -- Needed to keep the desaturation.
	hooksecurefunc(Bagnon.ItemSlot, "SetLocked", PostUpdateButton)

end
