-- GLOBALS: CustomNameplatesHandleEvent, CustomNameplatesUpdate
local _G = getfenv(0)
local ADDON = {}
local floor, mod = math.floor, math.mod
-- Caches: Don't edit
ADDON.currentDebuffs = {}
ADDON.Players = {}
ADDON.Targets = {}
ADDON.namePlateCache = {}

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

local _, class = UnitClass'player'
ADDON.class = class
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
local function decimal_round(n, dp)      -- ROUND TO 1 DECIMAL PLACE
    local shift = 10^(dp or 0)
    return math.floor(n*shift + .5)/shift
end
local getTimerLeft = function(tEnd)
	local t = tEnd - GetTime()
    if t > 5 then return decimal_round(t, 0) else return decimal_round(t, 1) end
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
      local _, class = UnitClass("target") -- use the locale-independent return
      table_insert(ADDON.Players, name)
      ADDON.Players[name] = {["class"] = class}
    end   
  end
end

function ADDON.targetEmphasize(namePlate)
  local emWidth, emHeight = (ADDON.genSettings.hbwidth * 1.05),(ADDON.genSettings.hbheight * 1.2)
  namePlate.hb:SetWidth(emWidth)
  namePlate.hb:SetHeight(emHeight)
  namePlate.hb.bg:SetWidth(emWidth + 1.5)
  namePlate.hb.bg:SetHeight(emHeight + 1.5)
end
function ADDON.targetNormalsize(namePlate)
  namePlate.hb:SetWidth(ADDON.genSettings.hbwidth)
  namePlate.hb:SetHeight(ADDON.genSettings.hbheight)
  namePlate.hb.bg:SetWidth(ADDON.genSettings.hbwidth + 1.5)
  namePlate.hb.bg:SetHeight(ADDON.genSettings.hbheight + 1.5)
end

function ADDON.targetIndicatorShow(namePlate)
  if (ADDON.targetindicator.hide) then return end
  if CustomNameplates.scanningPlayers then return end
  namePlate.targetIndicator:ClearAllPoints()
  namePlate.targetIndicator:SetPoint(ADDON.targetindicator.point,namePlate,ADDON.targetindicator.anchorpoint, ADDON.targetindicator.xoffs, ADDON.targetindicator.yoffs)
  namePlate.targetIndicator:Show()
end

function ADDON.getChronometerTimer(debuffname,target)
	for i = 20, 1, -1 do
		if Chronometer.bars[i].name and Chronometer.bars[i].target 
			and (Chronometer.bars[i].target == target or Chronometer.bars[i].target == "none")
			and Chronometer.bars[i].timer.x.tx and Chronometer.bars[i].timer.x.tx == debuffname then
			
				local registered,time,elapsed,running = Chronometer:CandyBarStatus(Chronometer.bars[i].id)
				
				if registered and running then
					--if elapsed > 5 then return decimal_round(elapsed, 0) else return decimal_round(elapsed, 1) end
					return decimal_round(time-elapsed, 0)
				else
					return nil
				end
		end
	end
end

function ADDON.targetIndicatorHide(namePlate)
  namePlate.targetIndicator:Hide()
end

function ADDON.CustomNameplates_OnUpdate(elapsed)
  CustomNameplates.ticker = CustomNameplates.ticker + elapsed
  if not (CustomNameplates.ticker > ADDON.genSettings.refreshRate) then return end  -- cap at 60fps by default
  CustomNameplates.ticker = 0
  local frames = { WorldFrame:GetChildren() }

--  CNPCleanUpExpiredDebuffs()

  for _, namePlate in ipairs(frames) do
    if ADDON.IsNamePlateFrame(namePlate) then
      if (ADDON.namePlateCache[namePlate] == nil) then
        --ADDON.Print("Nameplate is not in cache. Adding")
        ADDON.namePlateCache[namePlate] = true
      end
	  
	  
      local HealthBar = namePlate:GetChildren()
      local Border, Glow, Name, Level, Boss, RaidTargetIcon = namePlate:GetRegions()
	  
	  local text = Name:GetText()
	  local target = GetUnitName'target'
	  
      --Healthbar
      HealthBar:SetStatusBarTexture(ADDON.genSettings.texture)
      HealthBar:ClearAllPoints()
	  HealthBar:SetPoint("CENTER", namePlate, "CENTER", 0,0) -- -10)
      HealthBar:SetWidth(ADDON.genSettings.hbwidth) 
      HealthBar:SetHeight(ADDON.genSettings.hbheight)
      
      --HealthbarBackground
      if HealthBar.bg == nil then
        HealthBar.bg = HealthBar:CreateTexture(nil, "BORDER")
        HealthBar.bg:SetTexture(0,0,0,0.85)
        HealthBar.bg:ClearAllPoints()
		HealthBar.bg:SetPoint("CENTER", namePlate, "CENTER", 0, 0) -- -10)
        HealthBar.bg:SetWidth(HealthBar:GetWidth() + 1.5)
        HealthBar.bg:SetHeight(HealthBar:GetHeight() + 1.5)
      end
      namePlate.hb = HealthBar

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
        if (namePlate.debuffIcons[j] == nil) then
          namePlate.debuffIcons[j] = CreateFrame("Frame", "CNPDebuff"..j, namePlate)

		  namePlate.debuffIcons[j]:SetWidth(ADDON.debufficon.sizex) 
          namePlate.debuffIcons[j]:SetHeight(ADDON.debufficon.sizey)
		  namePlate.debuffIcons[j]:SetPoint(ADDON.debufficon.point, HealthBar, ADDON.debufficon.anchorpoint, mod(j-1,8) * (ADDON.debufficon.sizex+1)+ADDON.debufficon.xoffs, floor((j-1)/8)* (ADDON.debufficon.sizey+1)+ADDON.debufficon.yoffs)
          namePlate.debuffIcons[j].texture = namePlate.debuffIcons[j]:CreateTexture(nil, "ARTWORK")
          namePlate.debuffIcons[j].texture:SetAllPoints(namePlate.debuffIcons[j])
		  
		  namePlate.debuffIcons[j].stacks = namePlate.debuffIcons[j]:CreateFontString(nil, "OVERLAY")
		  namePlate.debuffIcons[j].stacks:SetFont(ADDON.leveltext.font,ADDON.leveltext.size,'OUTLINE',0,-1)
		  namePlate.debuffIcons[j].stacks:SetTextColor(1,1,1)
		  namePlate.debuffIcons[j].stacks:SetText("")
		  namePlate.debuffIcons[j].stacks:SetJustifyH('RIGHT')
          namePlate.debuffIcons[j].stacks:SetPoint('BOTTOMRIGHT', 2, -2)
          namePlate.debuffIcons[j].stacks:Hide()
		  
		  if Chronometer then
			  namePlate.debuffIcons[j].cd = namePlate.debuffIcons[j]:CreateFontString(nil, "OVERLAY")
			  namePlate.debuffIcons[j].cd:SetFont(ADDON.leveltext.font,ADDON.leveltext.size,'OUTLINE',0,-1)
			  namePlate.debuffIcons[j].cd:SetTextColor(1,1,1)
			  namePlate.debuffIcons[j].cd:SetText("")
			  namePlate.debuffIcons[j].cd:SetJustifyH('LEFT')
			  namePlate.debuffIcons[j].cd:SetPoint('TOPLEFT', -2, 7)
			  namePlate.debuffIcons[j].cd:Hide()
		  end
 --[[ 		  namePlate.debuffIcons[j].cd = CreateFrame("Frame", "CNPDebuff"..j.."CD", namePlate.debuffIcons[j])
         namePlate.debuffIcons[j].cd:SetWidth(ADDON.debufficon.sizex)
          namePlate.debuffIcons[j].cd:SetHeight(ADDON.debufficon.sizey)
          namePlate.debuffIcons[j].cd:SetFrameLevel(1)
          namePlate.debuffIcons[j].cd:SetPoint("CENTER", namePlate.debuffIcons[j], 0, 0)

          namePlate.debuffIcons[j].cdradial = CNPCreateCooldown(namePlate.debuffIcons[j].cd, 0.28 * ADDON.debufficon.sizex/12, false)
          namePlate.debuffIcons[j].cdradial:SetAlpha(1)
          namePlate.debuffIcons[j].cdradial:Hide()
 ]]
          namePlate.debuffIcons[j]:Hide()
        end
      end
      
      if UnitExists("target") and HealthBar:GetAlpha() == 1 then --Sets the texture of debuffs to debufficons
        ADDON.targetEmphasize(namePlate)
        ADDON.targetIndicatorShow(namePlate)
        if (ADDON.debufficon.hide) then
        else
          local j = 1
          local k = 1
          -- Current debuffs is a list of ALL DEBUFFS ON THE TARGET, AS SPECIFIED BY UnitDebuff
          -- We are potentially tracking some of them, and we'll match by icon. If the same
          -- icon is present multiple times, the most recently tracked spell will be shown
          -- for both.

 --         local trackedDebuffs = CNPGetTrackedUnitDebuffs(UnitName("target"))
 --         local debuffIsTracked = false
          local texture = nil

          for j, e in ipairs(ADDON.currentDebuffs) do
			local ry = (ADDON.debufficon.sizey/ADDON.debufficon.sizex)/2
            debuffIsTracked = false
            --ADDON.Print("Setting debuff " .. j .. " texture " .. ADDON.currentDebuffs[j] .. " and showing frame")
            texture = ADDON.currentDebuffs[j]
            if texture then 
				namePlate.debuffIcons[j].texture:SetTexture(texture,true)
				namePlate.debuffIcons[j].texture:SetTexCoord(.078, .92, .578 - ry, .42 + ry )
				namePlate.debuffIcons[j].texture:SetAlpha(0.9)
				namePlate.debuffIcons[j]:Show()
				local debuffname, stacks = UnitDebuff("target", j)
				if stacks then
					namePlate.debuffIcons[j].stacks:SetText(stacks == 1 and "" or stacks);
					namePlate.debuffIcons[j].stacks:Show()
				else
					namePlate.debuffIcons[j].stacks:Hide()
				end
				if Chronometer and debuffname then
					--ADDON.Print(debuffname.."-"..target)
					local duration = ADDON.getChronometerTimer(debuffname,target)
					if duration then
						namePlate.debuffIcons[j].cd:SetText(duration);
						namePlate.debuffIcons[j].cd:Show()
					else
						namePlate.debuffIcons[j].cd:Hide()
					end
				
				end
			end
--[[
            for _, debuff in ipairs(trackedDebuffs) do
              --ADDON.Print(debuff)
              if texture == debuff.texture then
                debuffIsTracked = true
                --ADDON.Print("debuff " .. debuff.texture .. " is tracked! Curr texture: " .. texture)
                --ADDON.Print("Start: " .. debuff.starttime .. ", end time: " .. debuff.endtime)

                namePlate.debuffIcons[j].cd:Show()
                namePlate.debuffIcons[j].cdradial:SetTimers(debuff.starttime, debuff.endtime)
                namePlate.debuffIcons[j].cdradial:Show()

                break
              end
            end

            if (not debuffIsTracked) then
              namePlate.debuffIcons[j].cd:Hide()
              namePlate.debuffIcons[j].cdradial:Hide()
            end
]]
            k = k + 1
          end
          for j=k,16,1 do
            namePlate.debuffIcons[j].texture:SetTexture(nil)
            namePlate.debuffIcons[j]:Hide()
--            namePlate.debuffIcons[j].cd:Hide()
--            namePlate.debuffIcons[j].cdradial:Hide()
          end
        end
      else
        ADDON.targetNormalsize(namePlate)
        ADDON.targetIndicatorHide(namePlate)
        for j=1,16,1 do
          if namePlate.debuffIcons[j].texture then 
			namePlate.debuffIcons[j].texture:SetTexture(nil)
			namePlate.debuffIcons[j]:Hide()
 --         namePlate.debuffIcons[j].cd:Hide()
 --         namePlate.debuffIcons[j].cdradial:Hide()
		  end
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
      Name:SetFont(ADDON.nametext.font,ADDON.nametext.size,'OUTLINE',0,-1)


--	  Name:SetPoint('BOTTOMLEFT',namePlate,'TOPLEFT')
--    Name:SetPoint('BOTTOMRIGHT',namePlate,'TOPRIGHT')
	  
      Name:SetPoint(ADDON.nametext.point, HealthBar, ADDON.nametext.anchorpoint, ADDON.nametext.xoffs, ADDON.nametext.yoffs)
      
      Level:SetFontObject(GameFontNormal)
      Level:SetFont(ADDON.leveltext.font,ADDON.leveltext.size,'OUTLINE',0,-1)
      Level:SetPoint(ADDON.leveltext.point, HealthBar, ADDON.leveltext.anchorpoint,ADDON.leveltext.xoffs,ADDON.leveltext.yoffs)
	  
	  
	  
	  if ADDON.class == 'ROGUE' or ADDON.class == 'DRUID' then 
		if namePlate.cp == nil then
            namePlate.cp = namePlate:CreateFontString(nil, 'OVERLAY')
            namePlate.cp:SetFont(ADDON.combopoints.font, ADDON.combopoints.size, 'OUTLINE')
            namePlate.cp:SetPoint(ADDON.combopoints.point, HealthBar,ADDON.combopoints.anchorpoint,ADDON.combopoints.xoffs,ADDON.combopoints.yoffs)
        end
		
		local cp 	 = GetComboPoints()
		namePlate.cp:Hide()
		if not ADDON.combopoints.hide and target == text and HealthBar:GetAlpha() == 1 and cp > 0 then
			namePlate.cp:Show()
			namePlate.cp:SetText(string.rep('•', cp))
			namePlate.cp:SetTextColor(.5*(cp - 1), 2/(cp - 1), .5/(cp - 1))
		end
	  end
	  
	  if namePlate.cast == nil then
		namePlate.cast = CreateFrame('StatusBar', nil, namePlate)
		namePlate.cast:SetHeight(14)
		namePlate.cast:SetStatusBarTexture([[Interface\AddOns\CustomNameplates\textures\smooth]])
		namePlate.cast:SetStatusBarColor(1, .4, 0)
		namePlate.cast:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 8,})
		namePlate.cast:SetBackdropColor(0, 0, 0, .7)
	
		
		namePlate.cast:SetPoint('LEFT', namePlate, 21, 0)
		namePlate.cast:SetPoint('RIGHT', namePlate, 0, 0)
		namePlate.cast:SetPoint('TOP', HealthBar, 'BOTTOM', 0, -6)

		namePlate.cast.text = namePlate.cast:CreateFontString(nil, 'OVERLAY')
		namePlate.cast.text:SetTextColor(1, 1, 1)
		namePlate.cast.text:SetFont(STANDARD_TEXT_FONT, 10)
		namePlate.cast.text:SetShadowOffset(1, -1)
		namePlate.cast.text:SetShadowColor(0, 0, 0)
		namePlate.cast.text:SetPoint('LEFT', namePlate.cast, 'LEFT', 2, 0)

		namePlate.cast.timer = namePlate.cast:CreateFontString(nil, 'OVERLAY')
		namePlate.cast.timer:SetTextColor(1, 1, 1)
		namePlate.cast.timer:SetFont(STANDARD_TEXT_FONT, 9)
		namePlate.cast.timer:SetPoint('RIGHT', namePlate.cast,'RIGHT', -2, 0)

		namePlate.cast.icon = namePlate.cast:CreateTexture(nil, 'OVERLAY', nil, 7)
		namePlate.cast.icon:SetWidth(16) namePlate.cast.icon:SetHeight(14)
		namePlate.cast.icon:SetPoint('RIGHT', namePlate.cast, 'LEFT', -2, 0)
		namePlate.cast.icon:SetTexture[[Interface\Icons\Spell_nature_purge]]
		namePlate.cast.icon:SetTexCoord(.1, .9, .1, .9)

--[[	namePlate.cast.border = namePlate.cast:CreateTexture(nil, 'OVERLAY')
		namePlate.cast.border:SetTexture[[Interface\AddOns\CustomNameplates\border\roth]]
		namePlate.cast.border:SetHeight(32)
		namePlate.cast.border:SetPoint('TOPLEFT', namePlate, 'BOTTOMLEFT', 0, 8)
		namePlate.cast.border:SetPoint('TOPRIGHT', namePlate, 'BOTTOMRIGHT', 0, 9)
		namePlate.cast.border:SetVertexColor(.2, .2, .2)
	]]
	  end
	  namePlate.cast:Hide()
	  if text ~= nil then
		local v = PROCESSCASTINGgetCast(text)
		if v ~= nil then
			if GetTime() < v.timeEnd then
				namePlate.cast:SetMinMaxValues(0, v.timeEnd - v.timeStart)
				if v.inverse then
					namePlate.cast:SetValue(mod((v.timeEnd - GetTime()), v.timeEnd - v.timeStart))
				else
					namePlate.cast:SetValue(mod((GetTime() - v.timeStart), v.timeEnd - v.timeStart))
				end
				namePlate.cast.text:SetText(v.spell)
				namePlate.cast.timer:SetText(getTimerLeft(v.timeEnd)..'s')
				namePlate.cast.icon:SetTexture(v.icon)
				namePlate.cast:SetAlpha(namePlate:GetAlpha())
				namePlate.cast:Show()
			end
		end
	  end
	  
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
      if UnitName("target") == nil and string_find(name, "%s") == nil and string_len(name) <= 12 and ADDON.Targets[name] == nil then 
	  --Set Name text and save it in a list
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
	ADDON.combopoints = CustomNameplatesDBPC.combopoints
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
  
  if event == "PLAYER_TARGET_CHANGED" or (event == "UNIT_AURA" and UnitExists("target") and arg1 == "target") then
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