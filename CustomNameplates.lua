--Settings only edit the parts after =
local genSettings = {["showPets"]=false,["enableAddOn"]=true,["showFriendly"]=false,["refreshRate"]=1/60} -- edit the refreshRage denominator to a lower value (eg. 30) for better performance at the cost of slower updates
local raidicon = {["size"]=15,["point"]="BOTTOMLEFT",["anchorpoint"]="BOTTOMLEFT",["xoffs"]=-18,["yoffs"]=-4}
local debufficon = {["size"]=12,["point"]="BOTTOMLEFT",["anchorpoint"]="BOTTOMLEFT",["row1yoffs"]=-13,["row2yoffs"]=-25}
local classicon = {["size"]=12,["point"]="RIGHT",["anchorpoint"]="LEFT",["xoffs"]=-3,["yoffs"]=-1}
local targetindicator = {["size"]=25,["point"]="BOTTOM",["anchorpoint"]="TOP",["xoffs"]=0,["yoffs"]=-5}
--Settings end

-- GLOBALS: CustomNameplatesHandleEvent, CustomNameplatesUpdate
-- Caches: Don't edit
local currentDebuffs = {}
local Players = {}
local Targets = {}

local Icons = {
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

-- upvalue some oft-called API for performance (scope upvalue limit = 32, damn you Lua 5.0)
local UnitDebuff, UnitClass, UnitName, UnitIsPlayer, UnitExists, UnitIsDeadOrGhost = 
  UnitDebuff, UnitClass, UnitName, UnitIsPlayer, UnitExists, UnitIsDeadOrGhost
local string_len, string_find, ipairs, table_insert = 
  string.len, string.find, ipairs, table.insert

-- addon utility functions
local function getDebuffs() --get debuffs on current target and store it in list
  local i = 1
  currentDebuffs = {}
  local debuff = UnitDebuff("target", i)
  while debuff do
    currentDebuffs[i] = debuff
    i = i + 1
    debuff = UnitDebuff("target", i)
  end
end

local function IsNamePlateFrame(frame)
 local overlayRegion = frame:GetRegions()
  if not overlayRegion or overlayRegion:GetObjectType() ~= "Texture" or overlayRegion:GetTexture() ~= "Interface\\Tooltips\\Nameplate-Border" then
    return false
  end
  return true
end

local function isPet(name)
  local PetsRU = {["Рыжая полосатая кошка"]=true,["Серебристая полосатая кошка"]=true,["Бомбейская кошка"]=true,["Корниш-рекс"]=true,
  ["Ястребиная сова"]=true,["Большая рогатая сова"]=true,["Макао"]=true,["Сенегальский попугай"]=true,["Черная королевская змейка"]=true,
  ["Бурая змейка"]=true,["Багровая змейка"]=true,["Луговая собачка"]=true,["Тараканище"]=true,["Анконская курица"]=true,["Щенок ворга"]=true,
  ["Паучок Дымной Паутины"]=true,["Механическая курица"]=true,["Птенец летучего хамелеона"]=true,["Зеленокрылый ара"]=true,["Гиацинтовый ара"]=true,
  ["Маленький темный дракончик"]=true,["Маленький изумрудный дракончик"]=true,["Маленький багровый дракончик"]=true,["Сиамская кошка"]=true,
  ["Пещерная крыса без сознания"]=true,["Механическая белка"]=true,["Крошечная ходячая бомба"]=true,["Крошка Дымок"]=true,["Механическая жаба"]=true,
  ["Заяц-беляк"]=true}
  local PetsENG = {["Orange Tabby"]=true,["Silver Tabby"]=true,["Bombay"]=true,["Cornish Rex"]=true,["Hawk Owl"]=true,["Great Horned Owl"]=true,
  ["Cockatiel"]=true,["Senegal"]=true,["Black Kingsnake"]=true,["Brown Snake"]=true,["Crimson Snake"]=true,["Prairie Dog"]=true,["Cockroach"]=true,
  ["Ancona Chicken"]=true,["Worg Pup"]=true,["Smolderweb Hatchling"]=true,["Mechanical Chicken"]=true,["Sprite Darter"]=true,["Green Wing Macaw"]=true,
  ["Hyacinth Macaw"]=true,["Tiny Black Whelpling"]=true,["Tiny Emerald Whelpling"]=true,["Tiny Crimson Whelpling"]=true,["Siamese"]=true,
  ["Unconscious Dig Rat"]=true,["Mechanical Squirrel"]=true,["Pet Bombling"]=true,["Lil' Smokey"]=true,["Lifelike Mechanical Toad"]=true}
  return PetsENG[name] or PetsRU[name] or false
end

local function fillPlayerDB(name)
  if Players[name] ~= nil then return end
  if Targets[name] == nil then
    TargetByName(name, true)
    table_insert(Targets, name)
    Targets[name] = "_"
    if UnitIsPlayer("target") then
      local _, class = UnitClass("target") -- use the locale-agnostic value
      table_insert(Players, name)
      Players[name] = {["class"] = class}
    end   
  end
end

local function targetIndicatorShow(namePlate)
  if CustomNameplates.scanningPlayers then return end
  namePlate.targetIndicator:ClearAllPoints()
  namePlate.targetIndicator:SetPoint(targetindicator.point,namePlate,targetindicator.anchorpoint, targetindicator.xoffs, targetindicator.yoffs)
  namePlate.targetIndicator:Show()
end

local function targetIndicatorHide(namePlate)
  namePlate.targetIndicator:Hide()
end

local function CustomNameplates_OnUpdate(elapsed)
  CustomNameplates.ticker = CustomNameplates.ticker + elapsed
  if not (CustomNameplates.ticker > genSettings.refreshRate) then return end  -- cap at 60fps
  CustomNameplates.ticker = 0
  local frames = { WorldFrame:GetChildren() }
  for _, namePlate in ipairs(frames) do
    if IsNamePlateFrame(namePlate) then
      local HealthBar = namePlate:GetChildren()
      local Border, Glow, Name, Level, _, RaidTargetIcon = namePlate:GetRegions()
      
      --Healthbar
      HealthBar:SetStatusBarTexture("Interface\\AddOns\\CustomNameplates\\barSmall")
      HealthBar:ClearAllPoints()
      HealthBar:SetPoint("CENTER", namePlate, "CENTER", 0, -10)
      HealthBar:SetWidth(80) --Edit this for width of the healthbar
      HealthBar:SetHeight(4) --Edit this for height of the healthbar
      
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
      RaidTargetIcon:SetWidth(raidicon.size)
      RaidTargetIcon:SetHeight(raidicon.size) 
      RaidTargetIcon:SetPoint(raidicon.point, HealthBar, raidicon.anchorpoint, raidicon.xoffs, raidicon.yoffs)
      
      
      if namePlate.debuffIcons == nil then
        namePlate.debuffIcons = {}
      end
      
      -- TargetIndicator
      if namePlate.targetIndicator == nil then
        namePlate.targetIndicator = namePlate:CreateTexture(nil, "OVERLAY")
        namePlate.targetIndicator:SetTexture(Icons.TargetIcon)
        namePlate.targetIndicator:SetWidth(targetindicator.size)
        namePlate.targetIndicator:SetHeight(targetindicator.size)
        namePlate.targetIndicator:Hide()
      end

      --DebuffIcons on TargetPlates 
      for j=1,16,1 do
        if namePlate.debuffIcons[j] == nil and j<=8 then --first row
          namePlate.debuffIcons[j] = namePlate:CreateTexture(nil, "BORDER")
          namePlate.debuffIcons[j]:SetTexture(0,0,0,0)
          namePlate.debuffIcons[j]:ClearAllPoints()
          namePlate.debuffIcons[j]:SetPoint(debufficon.point, HealthBar, debufficon.anchorpoint, (j-1) * debufficon.size, debufficon.row1yoffs)
          namePlate.debuffIcons[j]:SetWidth(debufficon.size) 
          namePlate.debuffIcons[j]:SetHeight(debufficon.size) 
        elseif namePlate.debuffIcons[j] == nil and j>8 then --second row
          namePlate.debuffIcons[j] = namePlate:CreateTexture(nil, "BORDER")
          namePlate.debuffIcons[j]:SetTexture(0,0,0,0)
          namePlate.debuffIcons[j]:ClearAllPoints()
          namePlate.debuffIcons[j]:SetPoint(debufficon.point, HealthBar, debufficon.anchorpoint, (j-9) * debufficon.size, debufficon.row2yoffs)
          namePlate.debuffIcons[j]:SetWidth(debufficon.size)
          namePlate.debuffIcons[j]:SetHeight(debufficon.size)
        end
      end
      
      if UnitExists("target") and HealthBar:GetAlpha() == 1 then --Sets the texture of debuffs to debufficons
        targetIndicatorShow(namePlate)
        local j = 1
        local k = 1
        for j, e in ipairs(currentDebuffs) do
          namePlate.debuffIcons[j]:SetTexture(currentDebuffs[j])
          namePlate.debuffIcons[j]:SetTexCoord(.078, .92, .079, .937)
          namePlate.debuffIcons[j]:SetAlpha(0.9)
          k = k + 1
        end
        for j=k,16,1 do
          namePlate.debuffIcons[j]:SetTexture(nil)
        end
      else
        targetIndicatorHide(namePlate)
        for j=1,16,1 do
          namePlate.debuffIcons[j]:SetTexture(nil)
        end
      end
      
      if namePlate.classIcon == nil then --ClassIcon
        namePlate.classIcon = namePlate:CreateTexture(nil, "BORDER")
        namePlate.classIcon:SetTexture(0,0,0,0)
        namePlate.classIcon:ClearAllPoints()
        namePlate.classIcon:SetPoint(classicon.point, Name, classicon.anchorpoint, classicon.xoffs, classicon.yoffs)
        namePlate.classIcon:SetWidth(classicon.size)
        namePlate.classIcon:SetHeight(classicon.size)
      end   

      if namePlate.classIconBorder == nil then --ClassIconBackground
        namePlate.classIconBorder = namePlate:CreateTexture(nil, "BACKGROUND")
        namePlate.classIconBorder:SetTexture(0,0,0,0.9)
        namePlate.classIconBorder:SetPoint("CENTER", namePlate.classIcon, "CENTER", 0, 0)
        namePlate.classIconBorder:SetWidth(classicon.size + 1.5)
        namePlate.classIconBorder:SetHeight(classicon.size + 1.5)
      end   
      namePlate.classIconBorder:Hide()
      -- namePlate.classIconBorder:SetTexture(0,0,0,0)
      namePlate.classIcon:SetTexture(0,0,0,0)
      Border:Hide()
      Glow:Hide()

      Name:SetFontObject(GameFontNormal)
      Name:SetFont("Interface\\AddOns\\CustomNameplates\\Fonts\\Ubuntu-C.ttf",12)
      Name:SetPoint("BOTTOM", namePlate, "CENTER", 0, -4)
      
      Level:SetFontObject(GameFontNormal)
      Level:SetFont("Interface\\AddOns\\CustomNameplates\\Fonts\\Helvetica_Neue_LT_Com_77_Bold_Condensed.ttf",11) --
      Level:SetPoint("TOPLEFT", Name, "RIGHT", 3, 4)

      HealthBar:Show()
      Name:Show()
      Level:Show()

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

      local name = Name:GetText()
      if genSettings.showPets ~= true then
        if isPet(name) then
          HealthBar:Hide()
          Name:Hide()
          Level:Hide()
        end
      end
      if UnitName("target") == nil and string_find(name, "%s") == nil and string_len(name) <= 12 and Targets[name] == nil then --Set Name text and saves it in a list
        CustomNameplates.scanningPlayers = true
        fillPlayerDB(name)
        ClearTarget()
        CustomNameplates.scanningPlayers = false
      end
      
      --if currently one of the nameplates is an actual player, draw classicon
      if  Players[name] ~= nil and namePlate.classIcon:GetTexture() == "Solid Texture" and string_find(namePlate.classIcon:GetTexture(), "Interface") == nil then
        namePlate.classIcon:SetTexture(Icons[Players[name]["class"]])
        namePlate.classIcon:SetTexCoord(.078, .92, .079, .937)
        namePlate.classIcon:SetAlpha(0.9)
        namePlate.classIconBorder:Show()
      end
      namePlate:EnableMouse(false)
    end
  end  
end

-- xml script handlers (need to be globals)
function CustomNameplatesHandleEvent(event) --Handles wow events
	if event == "PLAYER_ENTERING_WORLD" then
		if (genSettings.enableAddOn) then
			ShowNameplates()
			if (genSettings.showFriendly) then
				ShowFriendNameplates()
			else
				HideFriendNameplates()
			end
		else
			HideNameplates()
			HideFriendNameplates()
		end
	end
	
	if event == "PLAYER_TARGET_CHANGED" or event == "UNIT_AURA" then
    if UnitExists("target") then
      if not UnitIsDeadOrGhost("target") then
  		  getDebuffs()
      end
      if UnitIsPlayer("target") then
        local name = UnitName("target")
        fillPlayerDB(name)
      end
    end
	end
end

function CustomNameplatesUpdate(elapsed) --updates the frames
	CustomNameplates_OnUpdate(elapsed)
end



