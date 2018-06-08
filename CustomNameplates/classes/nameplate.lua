local L = AceLibrary("AceLocale-2.2"):new("CustomNameplates")
local BS = AceLibrary("Babble-Spell-2.3")

local _G = getfenv(0)

local Nameplate = NameplateUtil.newclass("Nameplate")
_G["CustomNameplate"] = Nameplate

local floor, mod = math.floor, math.mod

-- upvalue some oft-called API for performance (scope upvalue limit = 32, damn you Lua 5.0)
local UnitDebuff, UnitClass, UnitName, UnitIsPlayer, UnitExists, UnitIsDeadOrGhost, UnitAffectingCombat = 
UnitDebuff, UnitClass, UnitName, UnitIsPlayer, UnitExists, UnitIsDeadOrGhost, UnitAffectingCombat
local string_len, string_find, ipairs, table_insert = 
string.len, string.find, ipairs, table.insert

Nameplate.cache = {}

Nameplate.create = function(player, settings, frame)
  local nameplate = Nameplate.cache[frame]
  if nameplate == nil then
    nameplate = Nameplate.internalCreate()
    Nameplate.cache[frame] = nameplate

    nameplate.player = player -- observing player
    nameplate.frame = frame
    nameplate.debuffIcons = {}

    nameplate.classIcon = nil
    nameplate.classIconBorder = nil
    nameplate.health = nil
    nameplate.cp = nil
    nameplate.cast = nil
    nameplate.targetIndicator = nil
  end

  nameplate.settings = settings
  nameplate.healthBar = frame:GetChildren()
  local border, glow, name, level, boss, raidTargetIcon = frame:GetRegions()
  nameplate.border = border
  nameplate.glow = glow
  nameplate.name = name
  nameplate.level = level
  nameplate.boss = boss
  nameplate.raidTargetIcon = raidTargetIcon
  
  nameplate.target = GetUnitName'target'
  nameplate.mouseover = GetUnitName'mouseover'
  return nameplate
end

function Nameplate:getFrame()
  return self.frame
end

function Nameplate:getPlayer()
  return self.player
end

function Nameplate:getSettings()
  return self.settings
end

function Nameplate:setSettings(settings)
  self.settings = settings
end

function Nameplate:emphasize()
  local emWidth, emHeight = (self.settings.general.hbwidth * 1.05),(self.settings.general.hbheight * 1.2)
  self.healthBar:SetWidth(emWidth)
  self.healthBar:SetHeight(emHeight)
  self.healthBar.bg:SetWidth(emWidth + 1.5)
  self.healthBar.bg:SetHeight(emHeight + 1.5)
end

function Nameplate:normalsize()
  local general = self.settings.general
  self.healthBar:SetWidth(general.hbwidth)
  self.healthBar:SetHeight(general.hbheight)
  self.healthBar.bg:SetWidth(general.hbwidth + 1.5)
  self.healthBar.bg:SetHeight(general.hbheight + 1.5)
end

function Nameplate:showIndicator()
  local settings = self.settings
  if settings.targetindicator.hide or self.player.scanningPlayers then
    return
  end
  self.targetIndicator:ClearAllPoints()
  self.targetIndicator:SetPoint(settings.targetindicator.point, frame, 
                                settings.targetindicator.anchorpoint, 
                                settings.targetindicator.xoffs, 
                                settings.targetindicator.yoffs)
  self.targetIndicator:Show()
end

function Nameplate:hideIndicator()
  self.targetIndicator:Hide()
end

function Nameplate:render()
  local player = self.player
  local settings = self.settings
  local frame = self.frame
  local healthBar = self.healthBar
  local level = self.level
  local raidTargetIcon = self.raidTargetIcon
  local boss = self.boss
  local debuffIcons = self.debuffIcons
  local classIcon = self.classIcon
  local classIconBorder = self.classIconBorder
  local health = self.health
  local cp = self.cp
  local cast = self.cast
  local name = self.name
  local targetIndicator = self.targetIndicator

  --Healthbar
  healthBar:SetStatusBarTexture(settings.general.texture)
  healthBar:ClearAllPoints()
  healthBar:SetPoint("CENTER", frame, "CENTER", 0, 0) -- -10)
  healthBar:SetWidth(settings.general.hbwidth) 
  healthBar:SetHeight(settings.general.hbheight)
  
  --Healthbar Background
  if healthBar.bg == nil then
    healthBar.bg = healthBar:CreateTexture(nil, "BORDER")
  end
  healthBar.bg:SetTexture(0, 0, 0, 0.85)
  healthBar.bg:ClearAllPoints()
  healthBar.bg:SetPoint("CENTER", frame, "CENTER", 0, 0) -- -10)
  healthBar.bg:SetWidth(healthBar:GetWidth() + 1.5)
  healthBar.bg:SetHeight(healthBar:GetHeight() + 1.5)
  
  --RaidTarget
  raidTargetIcon:ClearAllPoints()
  raidTargetIcon:SetWidth(settings.raidicon.size)
  raidTargetIcon:SetHeight(settings.raidicon.size) 
  raidTargetIcon:SetPoint(settings.raidicon.point, healthBar, 
                          settings.raidicon.anchorpoint, 
                          settings.raidicon.xoffs, 
                          settings.raidicon.yoffs)
  
  -- TargetIndicator
  if targetIndicator == nil then
    targetIndicator = frame:CreateTexture(nil, "OVERLAY")
  end
  self.targetIndicator = targetIndicator
  targetIndicator:SetTexture(player.Icons.TargetIcon)
  targetIndicator:SetWidth(settings.targetindicator.size)
  targetIndicator:SetHeight(settings.targetindicator.size)
  targetIndicator:Hide()
  
  --DebuffIcons on TargetPlates 
  for j = 1, 16, 1 do
    if debuffIcons[j] == nil then
      debuffIcon = CreateFrame("Frame", "CNPDebuff"..j, frame)
      debuffIcons[j] = debuffIcon
      
      debuffIcon:SetWidth(settings.debufficon.sizex) 
      debuffIcon:SetHeight(settings.debufficon.sizey)
      debuffIcon:SetPoint(settings.debufficon.point, healthBar, 
                          settings.debufficon.anchorpoint, 
                          mod(j-1,8) * (settings.debufficon.sizex+1) + settings.debufficon.xoffs, 
                          floor((j - 1) / 8) * (settings.debufficon.sizey+1) + settings.debufficon.yoffs)

      debuffIcon.texture = debuffIcon:CreateTexture(nil, "ARTWORK")
      debuffIcon.texture:SetAllPoints(debuffIcon)
  
      debuffIcon.stacks = debuffIcon:CreateFontString(nil, "OVERLAY")
      debuffIcon.stacks:SetFont(settings.leveltext.font, settings.leveltext.size, 'OUTLINE', 0, -1)
      debuffIcon.stacks:SetTextColor(1, 1, 1)
      debuffIcon.stacks:SetText("")
      debuffIcon.stacks:SetJustifyH('RIGHT')
      debuffIcon.stacks:SetPoint('BOTTOMRIGHT', 2, -2)
      debuffIcon.stacks:Hide()
  
      if Chronometer then
        debuffIcon.cd = debuffIcon:CreateFontString(nil, "OVERLAY")
        debuffIcon.cd:SetFont(settings.leveltext.font, settings.leveltext.size, 'OUTLINE', 0, -1)
        debuffIcon.cd:SetTextColor(1, 1, 1)
        debuffIcon.cd:SetText("")
        debuffIcon.cd:SetJustifyH('LEFT')
        debuffIcon.cd:SetPoint('TOPLEFT', -2, 7)
        debuffIcon.cd:Hide()
      end
      debuffIcon:Hide()
    end
  end
  
  --Sets the texture of debuffs to debufficons
  if UnitExists("target") and healthBar:GetAlpha() == 1 then
    self:emphasize()
    self:showIndicator()

    if not settings.debufficon.hide then
      local j = 1
      local k = 1
      local texture = nil
      
      for j, e in ipairs(player.debuffs) do
        local ry = (settings.debufficon.sizey / settings.debufficon.sizex) / 2
        debuffIsTracked = false
        texture = player.debuffs[j]
        if texture then 
          debuffIcon.texture:SetTexture(texture, true)
          debuffIcon.texture:SetTexCoord(.078, .92, .578 - ry, .42 + ry )
          debuffIcon.texture:SetAlpha(0.9)
          debuffIcon:Show()
          local debuffname, stacks = UnitDebuff("target", j)
          if stacks then
            debuffIcon.stacks:SetText(stacks == 1 and "" or stacks);
            debuffIcon.stacks:Show()
          else
            debuffIcon.stacks:Hide()
          end
          if Chronometer and debuffname then
            local duration = player.getChronometerTimer(debuffname, target)
            if duration then
              debuffIcon.cd:SetText(duration);
              debuffIcon.cd:Show()
            else
              debuffIcon.cd:Hide()
            end
          end
        end
        k = k + 1
      end
      for j = k, 16, 1 do
        if debuffIcon.texture then
          debuffIcon.texture:SetTexture(nil)
          debuffIcon:Hide()
        end
      end
    end
  else
    self:normalsize()
    self:hideIndicator()

    for j = 1, 16, 1 do
      if debuffIcon.texture then 
        debuffIcon.texture:SetTexture(nil)
        debuffIcon:Hide()
      end
    end
  end

  --ClassIcon
  if classIcon == nil then
    classIcon = frame:CreateTexture(nil, "BORDER")
  end
  self.classIcon = classIcon
  classIcon:SetTexture(0, 0, 0, 0)
  classIcon:ClearAllPoints()
  classIcon:SetPoint(settings.classIcon.point, name, 
                     settings.classIcon.anchorpoint, 
                     settings.classIcon.xoffs, 
                     settings.classIcon.yoffs)
  classIcon:SetWidth(settings.classIcon.size)
  classIcon:SetHeight(settings.classIcon.size)

  --ClassIconBackground
  if classIconBorder == nil then
    classIconBorder = frame:CreateTexture(nil, "BACKGROUND")
  end
  self.classIconBorder = classIconBorder
  classIconBorder:SetTexture(0, 0, 0, 0.9)
  classIconBorder:SetPoint("CENTER", classIcon, "CENTER", 0, 0)
  classIconBorder:SetWidth(settings.classIcon.size + 1.5)
  classIconBorder:SetHeight(settings.classIcon.size + 1.5)
  classIconBorder:Hide()
  classIcon:SetTexture(0, 0, 0, 0)

  self.border:Hide()
  self.glow:Hide()
  
  name:SetFontObject(GameFontNormal)
  name:SetFont(settings.nametext.font, settings.nametext.size, 'OUTLINE', 0, -1)

  name:SetPoint(settings.nametext.point, healthBar, 
                settings.nametext.anchorpoint, 
                settings.nametext.xoffs, 
                settings.nametext.yoffs)
  
  if health == nil then
    health = frame:CreateFontString(nil, "OVERLAY")
  end
  self.health = health
  health:SetFontObject(GameFontNormal)
  health:SetFont(settings.leveltext.font, settings.leveltext.size, 'OUTLINE', 0, -1)
  health:SetTextColor(1, 1, 1)
  health:SetText("")
  health:SetJustifyH('RIGHT')
  health:SetPoint('TOPRIGHT', healthBar, 'BOTTOMRIGHT', -2.5, 8)
  health:Hide()
  
  level:SetFontObject(GameFontNormal)
  level:SetFont(settings.leveltext.font, settings.leveltext.size, 'OUTLINE', 0, -1)
  level:SetPoint(settings.leveltext.point, healthBar, 
                 settings.leveltext.anchorpoint, 
                 settings.leveltext.xoffs, 
                 settings.leveltext.yoffs)
        
  if level.tag == nil then
    level.tag = frame:CreateFontString(nil, "OVERLAY")
  end
  level.tag:SetFontObject(GameFontNormal)
  level.tag:SetFont(settings.leveltext.font, settings.leveltext.size, 'OUTLINE', 0, -1)
  level.tag:SetTextColor(1, 1, 1)
  level.tag:SetText("")
  level.tag:SetJustifyH('LEFT')
  level.tag:SetPoint('BOTTOMLEFT', level, 'BOTTOMRIGHT', -2, 0)
  level.tag:Hide()
  
  if player.class == 'ROGUE' or player.class == 'DRUID' then 
    if cp == nil then
      cp = frame:CreateFontString(nil, 'OVERLAY')
    end
    self.cp = cp
    cp:SetFont(settings.combopoints.font, settings.combopoints.size, 'OUTLINE')
    cp:SetPoint(settings.combopoints.point, healthBar, 
                settings.combopoints.anchorpoint, 
                settings.combopoints.xoffs, 
                settings.combopoints.yoffs)
    cp:Hide()

    local combopoints = GetComboPoints()
    if not settings.combopoints.hide and target == text and healthBar:GetAlpha() == 1 and combopoints > 0 then
      cp:Show()
      cp:SetText(string.rep('•', combopoints))
      cp:SetTextColor(.5*(combopoints - 1), 2/(combopoints - 1), .5/(combopoints - 1))
    end
  end

  if cast == nil then
    cast = CreateFrame('StatusBar', nil, frame)
  end
  self.cast = cast
  cast:SetHeight(14)
  cast:SetStatusBarTexture([[Interface\AddOns\CustomNameplates\assets\textures\smooth]])
  cast:SetStatusBarColor(1, .4, 0)
  cast:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 8,})
  cast:SetBackdropColor(0, 0, 0, .7)

  cast:SetPoint('LEFT', frame, 21, 0)
  cast:SetPoint('RIGHT', frame, 0, 0)
  cast:SetPoint('TOP', healthBar, 'BOTTOM', 0, -6)
      
  cast.text = cast:CreateFontString(nil, 'OVERLAY')
  cast.text:SetTextColor(1, 1, 1)
  cast.text:SetFont(STANDARD_TEXT_FONT, 10)
  cast.text:SetShadowOffset(1, -1)
  cast.text:SetShadowColor(0, 0, 0)
  cast.text:SetPoint('LEFT', cast, 'LEFT', 2, 0)
      
  cast.timer = cast:CreateFontString(nil, 'OVERLAY')
  cast.timer:SetTextColor(1, 1, 1)
  cast.timer:SetFont(STANDARD_TEXT_FONT, 9)
  cast.timer:SetPoint('RIGHT', cast,'RIGHT', -2, 0)
      
  cast.icon = cast:CreateTexture(nil, 'OVERLAY', nil, 7)
  cast.icon:SetWidth(16) cast.icon:SetHeight(14)
  cast.icon:SetPoint('RIGHT', cast, 'LEFT', -2, 0)
  cast.icon:SetTexture[[Interface\Icons\Spell_nature_purge]]
  cast.icon:SetTexCoord(.1, .9, .1, .9)
  cast:Hide()
  
  local text = name:GetText()
  if text ~= nil then
    local v = PROCESSCASTINGgetCast(text)
    if v ~= nil and GetTime() < v.timeEnd then
      cast:SetMinMaxValues(0, v.timeEnd - v.timeStart)
      if v.inverse then
        cast:SetValue(mod((v.timeEnd - GetTime()), v.timeEnd - v.timeStart))
      else
        cast:SetValue(mod((GetTime() - v.timeStart), v.timeEnd - v.timeStart))
      end
      cast.text:SetText(v.spell)
      cast.timer:SetText(NameplateUtil.getTimeDifference(v.timeEnd)..'s')
      cast.icon:SetTexture(v.icon)
      cast:SetAlpha(frame:GetAlpha())
      cast:Show()
    else
      cast:Hide()
    end
  else
    cast:Hide()
  end

  healthBar:Show()
  name:Show()
  
  if health then
    local min, max
    local cur = healthBar:GetValue()
    local cunit = "%"
    if  MobHealth_PPP  then
      if MobHealth_GetTargetCurHP and UnitExists("target") and healthBar:GetAlpha() == 1 then
        local pcur = MobHealth_GetTargetCurHP()
        cur = (pcur ~= nil) and pcur or cur;
        cunit = (pcur ~= nil) and "" or cunit;
        --max = My_MobHealth_GetTargetMaxHP()  
      else
        local index = text..":"..(level:GetText() or 99);
        local ppp = MobHealth_PPP( index );
        if ppp ~= 0 then 
          cur = floor( cur * ppp + 0.5);
          --max = floor( 100 * ppp + 0.5);
          cunit = "";
        end
      end
    else
      --min, max = healthBar:GetMinMaxValues()
    end
    health:SetText(cur .. cunit ) --.. " / " .. max)
    health:Show()
  end
  
  local red, green, blue, _ = name:GetTextColor() --Set Color of Namelabel
  if red > 0.99 and green == 0 and blue == 0 then
    name:SetTextColor(1,0.4,0.2,0.85)
  elseif red > 0.99 and green > 0.81 and green < 0.82 and blue == 0 then
    name:SetTextColor(1,1,1,0.85)
  end
  
  if not settings.leveltext.hide and player.NPC[text] ~= nil then 
    local tad = ""
    local classif = player.NPC[text].class
    if classif == "rare" then 
      tad = "R"
    elseif classif == "rareelite" then
      tad = "R+"
    elseif classif == "elite" then
      tad = "+"
    end
    if tad ~= "" then 
      level.tag:SetText(tad)
      level.tag:Show()
    else
      local _ = level.tag:IsVisible() and level.tag:Hide()
    end
  else
    local _ = level.tag:IsVisible() and v.tag:Hide()      
  end
  
  local red, green, blue, _ = level:GetTextColor() --Set Color of Level
  
  if red > 0.99 and green == 0 and blue == 0 then
    level:SetTextColor(1,0.4,0.2,0.85)
  elseif red > 0.99 and green > 0.81 and green < 0.82 and blue == 0 then
    level:SetTextColor(1,1,1,0.85)
  end
  
  if level.tag:IsVisible() then
    level.tag:SetTextColor(level:GetTextColor())
  end
  
  if (settings.leveltext.hide) then
    level:Hide()
  else
    level:Show()
  end
  
  if settings.general.showPets ~= true then
    if player.isPet(text) then
      healthBar:Hide()
      name:Hide()
      level:Hide()
      health:Hide()
    end
  end
  
  if UnitName("target") == nil then 
    --Set Name text and save it in a list
    player.scanningPlayers = true
    player.fillPlayerDB(text)
    ClearTarget()
    player.scanningPlayers = false
  end
  
  player.checkMouseover(text);
  
  -- if currently one of the nameplates is an actual player, draw classIcon
  if player.Players[text] ~= nil and classIcon:GetTexture() == "Solid Texture" 
      and string_find(classIcon:GetTexture(), "Interface") == nil then
    if not settings.classIcon.hide then
      classIcon:SetTexture(player.Icons[player.Players[text]["class"]])
      classIcon:SetTexCoord(.078, .92, .079, .937)
      classIcon:SetAlpha(0.9)
      --classIconBorder:Show()
    end
    
  elseif (UnitExists("target") and healthBar:GetAlpha() == 1 and target == text and
      not UnitIsTappedByPlayer("target") and UnitIsTapped("target") and UnitCanAttack("player", "target") ) 
      or (UnitExists("mouseover") and mouseover == text and
      not UnitIsTappedByPlayer("mouseover") and  UnitIsTapped("mouseover") and UnitCanAttack("player", "mouseover")) then
    healthBar:SetStatusBarColor(0.5, 0.5, 0.5, 0.85)
  else
    --Set Color of Healthbar
    local red, green, blue, _ = healthBar:GetStatusBarColor()
    if blue > 0.99 and red == 0 and green == 0 then
      healthBar:SetStatusBarColor(0.2, 0.6, 1, 0.85)
    elseif red == 0 and green > 0.99 and blue == 0 then
      healthBar:SetStatusBarColor(0.6, 1, 0, 0.85)
    end
  end        
  if player.Players[text] ~= nil then
    local color = player.classColors[player.Players[text].class]
    healthBar:SetStatusBarColor(color.r, color.g, color.b, 0.85)
  end
  
  if boss:IsVisible() then
    if level:IsVisible() then
      level:Hide()

      boss:ClearAllPoints()
      boss:SetPoint(settings.leveltext.point, healthBar, 
                    settings.leveltext.anchorpoint,
                    settings.leveltext.xoffs,
                    settings.leveltext.yoffs+2)
    end
  end
  
  self:updateClickHandler()
end

function Nameplate:updateClickHandler()
  local clickThrough = self.settings.general.clickThrough
  if clickThrough > 0 then
    self.frame:EnableMouse(true)
    if clickThrough == 2 then
      if self.frame:HasScript("OnMouseDown") and self.frame:GetScript("OnMouseDown") then
        return
      end
      local player = self.player
      self.frame:SetScript("OnMouseDown", function()
        if arg1 and arg1 == "RightButton" then
          MouselookStart()
          CustomNameplatesEmulRightClick.time = GetTime()
          CustomNameplatesEmulRightClick.frame = this
          CustomNameplatesEmulRightClick.player = player
          CustomNameplatesEmulRightClick:Show()
        end
      end)
    end
  else
    self.frame:EnableMouse(false)
  end
end

function Nameplate:registerClickHandler(clickHandler)
  self.clickHandler = clickHandler
end

function Nameplate.isNamePlateFrame(frame)
 local regions = frame:GetRegions()
  if not regions or regions:GetObjectType() ~= "Texture" or regions:GetTexture() ~= "Interface\\Tooltips\\Nameplate-Border" then
    return false
  end
  return true
end

-- emulate fake rightclick
CustomNameplatesEmulRightClick = CreateFrame("Frame", nil, UIParent)
CustomNameplatesEmulRightClick.time = nil
CustomNameplatesEmulRightClick.frame = nil
CustomNameplatesEmulRightClick.player = nil
CustomNameplatesEmulRightClick:SetScript("OnUpdate", function()
  -- break here if nothing to do
  if not CustomNameplatesEmulRightClick.time or not CustomNameplatesEmulRightClick.frame then
    this:Hide()
    return
  end

  -- if threshold is reached (0.5 second) no click action will follow
  if not IsMouselooking() and CustomNameplatesEmulRightClick.time + 0.5 < GetTime() then
    CustomNameplatesEmulRightClick:Hide()
    return
  end

  -- run a usual nameplate rightclick action
  if not IsMouselooking() then
    CustomNameplatesEmulRightClick.frame:Click("LeftButton")
    if UnitCanAttack("player", "target") and not CustomNameplatesEmulRightClick.player.InCombat then 
      AttackTarget()
    end
    CustomNameplatesEmulRightClick:Hide()
    return
  end
end)