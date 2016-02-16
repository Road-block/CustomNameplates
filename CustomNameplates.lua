-- GLOBALS: CustomNameplatesHandleEvent, CustomNameplatesUpdate
local _G = getfenv(0)
local ADDON = {}

-- Caches: Don't edit
ADDON.currentDebuffs = {}
ADDON.Players = {}
ADDON.Targets = {}

ADDON.Icons = {
  ["DRUID"] = "Interface\\AddOns\\CustomNameplates\\Class\\ClassIcon_Druid",
  ["HUNTER"] = "Interface\\AddOns\\CustomNameplates\\Class\\ClassIcon_Hunter",
  ["MAGE"] = "Interface\\AddOns\\CustomNameplates\\Class\\ClassIcon_Mage",
  ["PALADIN"] = "Interface\\AddOns\\CustomNameplates\\Class\\ClassIcon_Paladin",
  ["PRIEST"] = "Interface\\AddOns\\CustomNameplates\\Class\\ClassIcon_Priest",
  ["ROGUE"] = "Interface\\AddOns\\CustomNameplates\\Class\\ClassIcon_Rogue",
  ["SHAMAN"] = "Interface\\AddOns\\CustomNameplates\\Class\\ClassIcon_Shaman",
  ["WARLOCK"] = "Interface\\AddOns\\CustomNameplates\\Class\\ClassIcon_Warlock",
  ["WARRIOR"] = "Interface\\AddOns\\CustomNameplates\\Class\\ClassIcon_Warrior",
  ["TargetIcon"] = "Interface\\AddOns\\CustomNameplates\\Reticule"
}
ADDON.PetsRU = {["Рыжая полосатая кошка"]=true,["Серебристая полосатая кошка"]=true,["Бомбейская кошка"]=true,["Корниш-рекс"]=true,
  ["Ястребиная сова"]=true,["Большая рогатая сова"]=true,["Макао"]=true,["Сенегальский попугай"]=true,["Черная королевская змейка"]=true,
  ["Бурая змейка"]=true,["Багровая змейка"]=true,["Луговая собачка"]=true,["Тараканище"]=true,["Анконская курица"]=true,["Щенок ворга"]=true,
  ["Паучок Дымной Паутины"]=true,["Механическая курица"]=true,["Птенец летучего хамелеона"]=true,["Зеленокрылый ара"]=true,["Гиацинтовый ара"]=true,
  ["Маленький темный дракончик"]=true,["Маленький изумрудный дракончик"]=true,["Маленький багровый дракончик"]=true,["Сиамская кошка"]=true,
  ["Пещерная крыса без сознания"]=true,["Механическая белка"]=true,["Крошечная ходячая бомба"]=true,["Крошка Дымок"]=true,["Механическая жаба"]=true,
  ["Заяц-беляк"]=true}
ADDON.PetsENG = {["Orange Tabby"]=true,["Silver Tabby"]=true,["Bombay"]=true,["Cornish Rex"]=true,["Hawk Owl"]=true,["Great Horned Owl"]=true,
  ["Cockatiel"]=true,["Senegal"]=true,["Black Kingsnake"]=true,["Brown Snake"]=true,["Crimson Snake"]=true,["Prairie Dog"]=true,["Cockroach"]=true,
  ["Ancona Chicken"]=true,["Worg Pup"]=true,["Smolderweb Hatchling"]=true,["Mechanical Chicken"]=true,["Sprite Darter"]=true,["Green Wing Macaw"]=true,
  ["Hyacinth Macaw"]=true,["Tiny Black Whelpling"]=true,["Tiny Emerald Whelpling"]=true,["Tiny Crimson Whelpling"]=true,["Siamese"]=true,
  ["Unconscious Dig Rat"]=true,["Mechanical Squirrel"]=true,["Pet Bombling"]=true,["Lil' Smokey"]=true,["Lifelike Mechanical Toad"]=true}

-- upvalue some oft-called API for performance (scope upvalue limit = 32, damn you Lua 5.0)
local UnitDebuff, UnitClass, UnitName, UnitIsPlayer, UnitExists, UnitIsDeadOrGhost, UnitAffectingCombat = 
  UnitDebuff, UnitClass, UnitName, UnitIsPlayer, UnitExists, UnitIsDeadOrGhost, UnitAffectingCombat
local string_len, string_find, ipairs, table_insert = 
  string.len, string.find, ipairs, table.insert

-- addon utility functions
function ADDON.Print(msg)
  local out = "|cff008800CustomPlates: |r"..tostring(msg)
  if not DEFAULT_CHAT_FRAME:IsVisible() then
    FCF_SelectDockFrame(DEFAULT_CHAT_FRAME)
  end
  DEFAULT_CHAT_FRAME:AddMessage(out)
end

function ADDON.getDebuffs() --get debuffs on current target and store it in list
  local i = 1
  ADDON.currentDebuffs = {}
  local debuff = UnitDebuff("target", i)
  while debuff do
    ADDON.currentDebuffs[i] = debuff
    i = i + 1
    debuff = UnitDebuff("target", i)
  end
end

function ADDON.IsNamePlateFrame(frame)
 local overlayRegion = frame:GetRegions()
  if not overlayRegion or overlayRegion:GetObjectType() ~= "Texture" or overlayRegion:GetTexture() ~= "Interface\\Tooltips\\Nameplate-Border" then
    return false
  end
  return true
end

function ADDON.isPet(name)
  return ADDON.PetsENG[name] or ADDON.PetsRU[name] or false
end

function ADDON.fillPlayerDB(name)
  if ADDON.Players[name] ~= nil then return end
  if ADDON.Targets[name] == nil then
    TargetByName(name, true)
    table_insert(ADDON.Targets, name)
    ADDON.Targets[name] = "_"
    if UnitIsPlayer("target") then
      local _, class = UnitClass("target") -- use the locale-agnostic value
      table_insert(ADDON.Players, name)
      ADDON.Players[name] = {["class"] = class}
    end   
  end
end

function ADDON.targetIndicatorShow(namePlate)
  if (ADDON.targetindicator.hide) then return end
  if CustomNameplates.scanningPlayers then return end
  namePlate.targetIndicator:ClearAllPoints()
  namePlate.targetIndicator:SetPoint(ADDON.targetindicator.point,namePlate,ADDON.targetindicator.anchorpoint, ADDON.targetindicator.xoffs, ADDON.targetindicator.yoffs)
  namePlate.targetIndicator:Show()
end

function ADDON.targetIndicatorHide(namePlate)
  namePlate.targetIndicator:Hide()
end

function ADDON.CustomNameplates_OnUpdate(elapsed)
  CustomNameplates.ticker = CustomNameplates.ticker + elapsed
  if not (CustomNameplates.ticker > ADDON.genSettings.refreshRate) then return end  -- cap at 60fps by default
  CustomNameplates.ticker = 0
  local frames = { WorldFrame:GetChildren() }
  for _, namePlate in ipairs(frames) do
    if ADDON.IsNamePlateFrame(namePlate) then
      local HealthBar = namePlate:GetChildren()
      local Border, Glow, Name, Level, Boss, RaidTargetIcon = namePlate:GetRegions()

      --Healthbar
      HealthBar:SetStatusBarTexture(ADDON.genSettings.texture)
      HealthBar:ClearAllPoints()
      HealthBar:SetPoint("CENTER", namePlate, "CENTER", 0, -10)
      HealthBar:SetWidth(ADDON.genSettings.hbwidth) 
      HealthBar:SetHeight(ADDON.genSettings.hbheight)
      
      --HealthbarBackground
      if HealthBar.bg == nil then
        HealthBar.bg = HealthBar:CreateTexture(nil, "BORDER")
        HealthBar.bg:SetTexture(0,0,0,0.85)
        HealthBar.bg:ClearAllPoints()
        HealthBar.bg:SetPoint("CENTER", namePlate, "CENTER", 0, -10)
        HealthBar.bg:SetWidth(HealthBar:GetWidth() + 1.5)
        HealthBar.bg:SetHeight(HealthBar:GetHeight() + 1.5)
      end
      
      --RaidTarget
      RaidTargetIcon:ClearAllPoints()
      RaidTargetIcon:SetWidth(ADDON.raidicon.size)
      RaidTargetIcon:SetHeight(ADDON.raidicon.size) 
      RaidTargetIcon:SetPoint(ADDON.raidicon.point, HealthBar, ADDON.raidicon.anchorpoint, ADDON.raidicon.xoffs, ADDON.raidicon.yoffs)
      
      if namePlate.debuffIcons == nil then
        namePlate.debuffIcons = {}
      end
      
      -- TargetIndicator
      if namePlate.targetIndicator == nil then
        namePlate.targetIndicator = namePlate:CreateTexture(nil, "OVERLAY")
        namePlate.targetIndicator:SetTexture(ADDON.Icons.TargetIcon)
        namePlate.targetIndicator:SetWidth(ADDON.targetindicator.size)
        namePlate.targetIndicator:SetHeight(ADDON.targetindicator.size)
        namePlate.targetIndicator:Hide()
      end

      --DebuffIcons on TargetPlates 
      for j=1,16,1 do
        if namePlate.debuffIcons[j] == nil and j<=8 then --first row
          namePlate.debuffIcons[j] = namePlate:CreateTexture(nil, "BORDER")
          namePlate.debuffIcons[j]:SetTexture(0,0,0,0)
          namePlate.debuffIcons[j]:ClearAllPoints()
          namePlate.debuffIcons[j]:SetPoint(ADDON.debufficon.point, HealthBar, ADDON.debufficon.anchorpoint, (j-1) * ADDON.debufficon.size, ADDON.debufficon.row1yoffs)
          namePlate.debuffIcons[j]:SetWidth(ADDON.debufficon.size) 
          namePlate.debuffIcons[j]:SetHeight(ADDON.debufficon.size) 
        elseif namePlate.debuffIcons[j] == nil and j>8 then --second row
          namePlate.debuffIcons[j] = namePlate:CreateTexture(nil, "BORDER")
          namePlate.debuffIcons[j]:SetTexture(0,0,0,0)
          namePlate.debuffIcons[j]:ClearAllPoints()
          namePlate.debuffIcons[j]:SetPoint(ADDON.debufficon.point, HealthBar, ADDON.debufficon.anchorpoint, (j-9) * ADDON.debufficon.size, ADDON.debufficon.row2yoffs)
          namePlate.debuffIcons[j]:SetWidth(ADDON.debufficon.size)
          namePlate.debuffIcons[j]:SetHeight(ADDON.debufficon.size)
        end
      end
      
      if UnitExists("target") and HealthBar:GetAlpha() == 1 then --Sets the texture of debuffs to debufficons
        ADDON.targetIndicatorShow(namePlate)
        if (ADDON.debufficon.hide) then
        else
          local j = 1
          local k = 1
          for j, e in ipairs(ADDON.currentDebuffs) do
            namePlate.debuffIcons[j]:SetTexture(ADDON.currentDebuffs[j])
            namePlate.debuffIcons[j]:SetTexCoord(.078, .92, .079, .937)
            namePlate.debuffIcons[j]:SetAlpha(0.9)
            k = k + 1
          end
          for j=k,16,1 do
            namePlate.debuffIcons[j]:SetTexture(nil)
          end
        end
      else
        ADDON.targetIndicatorHide(namePlate)
        for j=1,16,1 do
          namePlate.debuffIcons[j]:SetTexture(nil)
        end
      end
      
      if namePlate.classIcon == nil then --ClassIcon
        namePlate.classIcon = namePlate:CreateTexture(nil, "BORDER")
        namePlate.classIcon:SetTexture(0,0,0,0)
        namePlate.classIcon:ClearAllPoints()
        namePlate.classIcon:SetPoint(ADDON.classicon.point, Name, ADDON.classicon.anchorpoint, ADDON.classicon.xoffs, ADDON.classicon.yoffs)
        namePlate.classIcon:SetWidth(ADDON.classicon.size)
        namePlate.classIcon:SetHeight(ADDON.classicon.size)
      end   

      if namePlate.classIconBorder == nil then --ClassIconBackground
        namePlate.classIconBorder = namePlate:CreateTexture(nil, "BACKGROUND")
        namePlate.classIconBorder:SetTexture(0,0,0,0.9)
        namePlate.classIconBorder:SetPoint("CENTER", namePlate.classIcon, "CENTER", 0, 0)
        namePlate.classIconBorder:SetWidth(ADDON.classicon.size + 1.5)
        namePlate.classIconBorder:SetHeight(ADDON.classicon.size + 1.5)
      end   
      namePlate.classIconBorder:Hide()
      namePlate.classIcon:SetTexture(0,0,0,0)
      Border:Hide()
      Glow:Hide()

      Name:SetFontObject(GameFontNormal)
      Name:SetFont(ADDON.nametext.font,ADDON.nametext.size)
      Name:SetPoint(ADDON.nametext.point, namePlate, ADDON.nametext.anchorpoint, ADDON.nametext.xoffs, ADDON.nametext.yoffs)
      
      Level:SetFontObject(GameFontNormal)
      Level:SetFont(ADDON.leveltext.font,ADDON.leveltext.size)
      Level:SetPoint(ADDON.leveltext.point, Name, ADDON.leveltext.anchorpoint,ADDON.leveltext.xoffs,ADDON.leveltext.yoffs)

      HealthBar:Show()
      Name:Show()

      local red, green, blue, _ = Name:GetTextColor() --Set Color of Namelabel
      -- Print(red.." "..green.." "..blue)
      if red > 0.99 and green == 0 and blue == 0 then
        Name:SetTextColor(1,0.4,0.2,0.85)
      elseif red > 0.99 and green > 0.81 and green < 0.82 and blue == 0 then
        Name:SetTextColor(1,1,1,0.85)
      end

      local red, green, blue, _ = HealthBar:GetStatusBarColor() --Set Color of Healthbar
      if blue > 0.99 and red == 0 and green == 0 then
        HealthBar:SetStatusBarColor(0.2,0.6,1,0.85)
      elseif red == 0 and green > 0.99 and blue == 0 then
        HealthBar:SetStatusBarColor(0.6,1,0,0.85)
      end

      local red, green, blue, _ = Level:GetTextColor() --Set Color of Level
      
      if red > 0.99 and green == 0 and blue == 0 then
        Level:SetTextColor(1,0.4,0.2,0.85)
      elseif red > 0.99 and green > 0.81 and green < 0.82 and blue == 0 then
        Level:SetTextColor(1,1,1,0.85)
      end

      if (ADDON.leveltext.hide) then
        Level:Hide()
      else
        Level:Show()
      end

      local name = Name:GetText()
      if ADDON.genSettings.showPets ~= true then
        if ADDON.isPet(name) then
          HealthBar:Hide()
          Name:Hide()
          Level:Hide()
        end
      end
      if UnitName("target") == nil and string_find(name, "%s") == nil and string_len(name) <= 12 and ADDON.Targets[name] == nil then --Set Name text and save it in a list
        CustomNameplates.scanningPlayers = true
        ADDON.fillPlayerDB(name)
        ClearTarget()
        CustomNameplates.scanningPlayers = false
      end
      
      --if currently one of the nameplates is an actual player, draw ADDON.classicon
      if (ADDON.classicon.hide) then
      else
        if ADDON.Players[name] ~= nil and namePlate.classIcon:GetTexture() == "Solid Texture" and string_find(namePlate.classIcon:GetTexture(), "Interface") == nil then
          namePlate.classIcon:SetTexture(ADDON.Icons[ADDON.Players[name]["class"]])
          namePlate.classIcon:SetTexCoord(.078, .92, .079, .937)
          namePlate.classIcon:SetAlpha(0.9)
          namePlate.classIconBorder:Show()
        end        
      end

      if Boss:IsVisible() then
        if Level:IsVisible() then
            Level:Hide()
            Boss:ClearAllPoints()
            Boss:SetPoint("TOPLEFT", Name, "RIGHT", 1, 7)
        end
      end

      if (ADDON.genSettings.clickThrough == true) then
        namePlate:EnableMouse(false)
      else
        namePlate:EnableMouse(true)
      end

    end
  end  
end

-- xml script handlers (need to be globals)
function CustomNameplatesHandleEvent(event) --Handles wow events
  
  if event == "VARIABLES_LOADED" then
    local options = _G["CustomNameplatesOptions"]()
    -- Settings block
    ADDON.genSettings = CustomNameplatesDBPC.genSettings
    ADDON.raidicon = CustomNameplatesDBPC.raidicon
    ADDON.debufficon = CustomNameplatesDBPC.debufficon
    ADDON.classicon = CustomNameplatesDBPC.classicon
    ADDON.targetindicator = CustomNameplatesDBPC.targetindicator
    ADDON.nametext = CustomNameplatesDBPC.nametext
    ADDON.leveltext = CustomNameplatesDBPC.leveltext
    ADDON.VARIABLES_LOADED = true
    if ADDON.PLAYER_ENTERING_WORLD then
      ADDON.PLAYER_ENTERING_WORLD = nil
      CustomNameplatesHandleEvent("PLAYER_ENTERING_WORLD")
    end
  end

  if event == "PLAYER_ENTERING_WORLD" then
    if ADDON.VARIABLES_LOADED then
      if (ADDON.genSettings.enableAddOn and not ADDON.genSettings.combatOnly) then
        ShowNameplates()
      else
        HideNameplates()
      end
      if (ADDON.genSettings.showFriendly) then
        ShowFriendNameplates()
      else
        HideFriendNameplates()
      end    
      if (ADDON.genSettings.combatOnly) and (UnitAffectingCombat("player") or UnitAffectingCombat("pet")) then
        ShowNameplates()
      end
    else
      ADDON.PLAYER_ENTERING_WORLD = true
    end
  end
  
  if event == "PLAYER_TARGET_CHANGED" or event == "UNIT_AURA" then
    if UnitExists("target") then
      if not UnitIsDeadOrGhost("target") then
        ADDON.getDebuffs()
      end
      if UnitIsPlayer("target") then
        local name = UnitName("target")
        ADDON.fillPlayerDB(name)
      end
    end
  end

  if ADDON.VARIABLES_LOADED and ADDON.genSettings.combatOnly then
    if event == "PLAYER_REGEN_DISABLED" then -- incombat
      ShowNameplates()
    elseif event == "PLAYER_REGEN_ENABLED" then -- exiting combat
      HideNameplates()
    end
  end

end

function CustomNameplatesUpdate(elapsed) --updates the frames
  if not ADDON.VARIABLES_LOADED then return end
  ADDON.CustomNameplates_OnUpdate(elapsed)
end

SlashCmdList["CNP"] = function(msg)
  local options = _G["CustomNameplatesOptions"]()
  if options:IsVisible() then
    options:Hide()
  else
    options:Show()
  end
end
SlashCmdList["CUSTOMNAMEPLATES"] = SlashCmdList["CNP"]
SLASH_CNP1 = "/cnp"
SLASH_CUSTOMNAMEPLATES1 = "/customnameplates"