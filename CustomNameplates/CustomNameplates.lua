local L = AceLibrary("AceLocale-2.2"):new("CustomNameplates")
local BS = AceLibrary("Babble-Spell-2.3")

CustomNameplates = CreateFrame("Frame", nil, UIParent)

local _G = getfenv(0)

local Nameplate = _G.CustomNameplate

local Player = {}
local Settings =  {}

local floor, mod = math.floor, math.mod
-- Caches: Don't edit
Player.debuffs = {}
Player.Players = {}
Player.NPC = {}
Player.InCombat = false
Player.ticker = 0
Player.scanningPlayers = false

Player.Icons = {
  ["DRUID"] = "Interface\\AddOns\\CustomNameplates\\assets\\icons\\druid",
  ["HUNTER"] = "Interface\\AddOns\\CustomNameplates\\assets\\icons\\hunter",
  ["MAGE"] = "Interface\\AddOns\\CustomNameplates\\assets\\icons\\mage",
  ["PALADIN"] = "Interface\\AddOns\\CustomNameplates\\assets\\icons\\paladin",
  ["PRIEST"] = "Interface\\AddOns\\CustomNameplates\\assets\\icons\\priest",
  ["ROGUE"] = "Interface\\AddOns\\CustomNameplates\\assets\\icons\\rogue",
  ["SHAMAN"] = "Interface\\AddOns\\CustomNameplates\\assets\\icons\\shaman",
  ["WARLOCK"] = "Interface\\AddOns\\CustomNameplates\\assets\\icons\\warlock",
  ["WARRIOR"] = "Interface\\AddOns\\CustomNameplates\\assets\\icons\\warrior",
  ["TargetIcon"] = "Interface\\AddOns\\CustomNameplates\\assets\\reticule"
}

Player.PetsRU = {
  ["Рыжая полосатая кошка"]=true,["Серебристая полосатая кошка"]=true,["Бомбейская кошка"]=true,["Корниш-рекс"]=true,
  ["Ястребиная сова"]=true,["Большая рогатая сова"]=true,["Макао"]=true,["Сенегальский попугай"]=true,["Черная королевская змейка"]=true,
  ["Бурая змейка"]=true,["Багровая змейка"]=true,["Луговая собачка"]=true,["Тараканище"]=true,["Анконская курица"]=true,["Щенок ворга"]=true,
  ["Паучок Дымной Паутины"]=true,["Механическая курица"]=true,["Птенец летучего хамелеона"]=true,["Зеленокрылый ара"]=true,["Гиацинтовый ара"]=true,
  ["Маленький темный дракончик"]=true,["Маленький изумрудный дракончик"]=true,["Маленький багровый дракончик"]=true,["Сиамская кошка"]=true,
  ["Пещерная крыса без сознания"]=true,["Механическая белка"]=true,["Крошечная ходячая бомба"]=true,["Крошка Дымок"]=true,["Механическая жаба"]=true,
  ["Заяц-беляк"]=true
}

Player.PetsENG = {
  ["Orange Tabby"]=true,["Silver Tabby"]=true,["Bombay"]=true,["Cornish Rex"]=true,["Hawk Owl"]=true,["Great Horned Owl"]=true,
  ["Cockatiel"]=true,["Senegal"]=true,["Black Kingsnake"]=true,["Brown Snake"]=true,["Crimson Snake"]=true,["Prairie Dog"]=true,["Cockroach"]=true,
  ["Ancona Chicken"]=true,["Worg Pup"]=true,["Smolderweb Hatchling"]=true,["Mechanical Chicken"]=true,["Sprite Darter"]=true,["Green Wing Macaw"]=true,
  ["Hyacinth Macaw"]=true,["Tiny Black Whelpling"]=true,["Tiny Emerald Whelpling"]=true,["Tiny Crimson Whelpling"]=true,["Siamese"]=true,
  ["Unconscious Dig Rat"]=true,["Mechanical Squirrel"]=true,["Pet Bombling"]=true,["Lil' Smokey"]=true,["Lifelike Mechanical Toad"]=true
}

Player.classColors = {
  HUNTER  = {r = 0.67, g = 0.83, b = 0.45},
  WARLOCK = {r = 0.58, g = 0.51, b = 0.79},
  PRIEST  = {r = 1.0,  g = 1.0,  b = 1.0},
  PALADIN = {r = 0.96, g = 0.55, b = 0.73},
  MAGE    = {r = 0.41, g = 0.8,  b = 0.94},
  ROGUE   = {r = 1.0,  g = 0.96, b = 0.41},
  DRUID   = {r = 1.0,  g = 0.49, b = 0.04},
  SHAMAN  = {r = 0.14, g = 0.35, b = 1.0},
  WARRIOR = {r = 0.78, g = 0.61, b = 0.43},
  PET     = {r = 0.20, g = 0.90, b = 0.20},
}

local _, class = UnitClass'player'
Player.class = class

-- upvalue some oft-called API for performance (scope upvalue limit = 32, damn you Lua 5.0)
local UnitDebuff, UnitClass, UnitName, UnitIsPlayer, UnitExists, UnitIsDeadOrGhost, UnitAffectingCombat = 
UnitDebuff, UnitClass, UnitName, UnitIsPlayer, UnitExists, UnitIsDeadOrGhost, UnitAffectingCombat
local string_len, string_find, ipairs, table_insert = string.len, string.find, ipairs, table.insert

--get debuffs on current target and store it in list
function Player.getDebuffs()
  local i = 1
  Player.debuffs = {}
  local debuff = UnitDebuff("target", i)
  while debuff do
    Player.debuffs[i] = debuff
    i = i + 1
    debuff = UnitDebuff("target", i)
  end
end

function Player.isPet(name)
  return Player.PetsENG[name] or Player.PetsRU[name] or false
end

function Player.fillPlayerDB(name)
  if Player.Players[name] ~= nil or Player.NPC[name] ~= nil then return end
  TargetByName(name, true)

  if UnitIsPlayer("target") then
    local _, class = UnitClass("target") -- use the locale-independent return
    Player.Players[name] = {}
    Player.Players[name].class = class
  else
    Player.NPC[name] = {}
    Player.NPC[name].class = UnitClassification("target")
    if MobHealth_PPP  then Player.NPC[name].ppp = MobHealth_PPP( name..":"..UnitLevel("target") ); end
  end   
end

function Player.checkMouseover(name)
  if Player.Players[name] ~= nil or Player.NPC[name] ~= nil or UnitName("mouseover") ~= name then return end
  
  if UnitIsPlayer("mouseover") then
    local _, class = UnitClass("mouseover")
    Player.Players[name] = {}
    Player.Players[name].class = class
  else
    Player.NPC[name] = {}
    Player.NPC[name].class = UnitClassification("mouseover")
    if MobHealth_PPP  then Player.NPC[name].ppp = MobHealth_PPP( name..":"..UnitLevel("mouseover") ); end
  end
end

function Player.getChronometerTimer(debuffname, target)
  for i = 20, 1, -1 do
    if Chronometer.bars[i].name and Chronometer.bars[i].target 
      and (Chronometer.bars[i].target == target or Chronometer.bars[i].target == "none")
      and Chronometer.bars[i].timer.x.tx and Chronometer.bars[i].timer.x.tx == debuffname then
      
        local registered,time,elapsed,running = Chronometer:CandyBarStatus(Chronometer.bars[i].id)
        
        if registered and running then
          return NameplateUtil.decimal_round(time - elapsed, 0)
        else
          return nil
        end
    end
  end
end

function Player.ClassPos (class)
  if(class=="WARRIOR") then return 0,    0.25,    0,     0.25;  end
  if(class=="MAGE")    then return 0.25, 0.5,     0,     0.25;  end
  if(class=="ROGUE")   then return 0.5,  0.75,    0,     0.25;  end
  if(class=="DRUID")   then return 0.75, 1,       0,     0.25;  end
  if(class=="HUNTER")  then return 0,    0.25,    0.25,  0.5;   end
  if(class=="SHAMAN")  then return 0.25, 0.5,     0.25,  0.5;   end
  if(class=="PRIEST")  then return 0.5,  0.75,    0.25,  0.5;   end
  if(class=="WARLOCK") then return 0.75, 1,       0.25,  0.5;   end
  if(class=="PALADIN") then return 0,    0.25,    0.5,   0.75;  end
  return 0.25, 0.5, 0.5, 0.75  -- Returns empty next one, so blank
end

function CustomNameplates:OnUpdate(elapsed)
  Player.ticker = Player.ticker + elapsed
  -- cap at 60fps by default
  if not (Player.ticker > Settings.general.refreshRate) then 
    return
  end
  Player.ticker = 0
  local frames = { WorldFrame:GetChildren() }
  
  for _, frame in ipairs(frames) do
    if Nameplate.isNamePlateFrame(frame) then
      local nameplate = Nameplate.create(Player, Settings, frame)
      nameplate:render()
    end
  end
end
  
function CustomNameplates:OnEvent(event) --Handles wow events
  if event == "VARIABLES_LOADED" then
    local options = _G["CustomNameplatesOptions"]()
    -- Settings block
    Settings = NameplateDBPC
    Player.VARIABLES_LOADED = true
    if type(Settings.general.clickThrough) == "boolean" then
      Settings.general.clickThrough = 2
    end
    if Player.PLAYER_ENTERING_WORLD then
      Player.PLAYER_ENTERING_WORLD = nil
      CustomNameplates:OnEvent("PLAYER_ENTERING_WORLD")
    end
  end
  
  if event == "PLAYER_ENTERING_WORLD" then
    if Player.VARIABLES_LOADED then
      if (Settings.general.enabled and not Settings.general.combatOnly) then
        ShowNameplates()
      else
        HideNameplates()
      end
      if (Settings.general.showFriendly) then
        ShowFriendNameplates()
      else
        HideFriendNameplates()
      end    
      if (Settings.general.combatOnly) and (UnitAffectingCombat("player") or UnitAffectingCombat("pet")) then
        ShowNameplates()
      end
    else
      Player.PLAYER_ENTERING_WORLD = true
    end
  end
  
  if event == "PLAYER_TARGET_CHANGED" or (event == "UNIT_AURA" and UnitExists("target") and arg1 == "target") then
    if UnitExists("target") then
      if not UnitIsDeadOrGhost("target") then
        Player.getDebuffs()
      end
      if not Player.scanningPlayers then
        local name = UnitName("target")
        Player.fillPlayerDB(name)
      end
    end
  end
  
  if Player.VARIABLES_LOADED and Settings.general.combatOnly then
    if event == "PLAYER_REGEN_DISABLED" then -- incombat
      Player.InCombat = true
      ShowNameplates()
    elseif event == "PLAYER_REGEN_ENABLED" then -- exiting combat
      Player.InCombat = false
      HideNameplates()
    end
  end
  
end

CustomNameplates:SetScript("OnEvent", function()
  CustomNameplates:OnEvent(event)
end)

CustomNameplates:SetScript("OnUpdate",function(...)
  if not Player.VARIABLES_LOADED then return end
  CustomNameplates:OnUpdate(arg1)
end)

CustomNameplates:RegisterEvent("PLAYER_TARGET_CHANGED")
CustomNameplates:RegisterEvent("UNIT_AURA")
CustomNameplates:RegisterEvent("PLAYER_ENTERING_WORLD");
CustomNameplates:RegisterEvent("PLAYER_REGEN_ENABLED");
CustomNameplates:RegisterEvent("PLAYER_REGEN_DISABLED");
CustomNameplates:RegisterEvent("VARIABLES_LOADED");
--CustomNameplates:RegisterEvent'START_AUTOREPEAT_SPELL'
--CustomNameplates:RegisterEvent'STOP_AUTOREPEAT_SPELL'

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
