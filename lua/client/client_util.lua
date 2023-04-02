-- All functions in this file are used by Qml

function Translate(src)
  return Fk:translate(src)
end

function GetGeneralData(name)
  local general = Fk.generals[name]
  if general == nil then general = Fk.generals["diaochan"] end
  return json.encode {
    package = general.package.name,
    extension = general.package.extensionName,
    kingdom = general.kingdom,
    hp = general.hp,
    maxHp = general.maxHp
  }
end

function GetGeneralDetail(name)
  local general = Fk.generals[name]
  if general == nil then general = Fk.generals["diaochan"] end
  local ret = {
    package = general.package.name,
    extension = general.package.extensionName,
    kingdom = general.kingdom,
    hp = general.hp,
    maxHp = general.maxHp,
    skill = {}
  }
  for _, s in ipairs(general.skills) do
    table.insert(ret.skill, {
      name = s.name,
      description = Fk:getDescription(s.name)
    })
  end
  for _, s in ipairs(general.other_skills) do
    table.insert(ret.skill, {
      name = s,
      description = Fk:getDescription(s)
    })
  end
  return json.encode(ret)
end

function GetSameGenerals(name)
  return json.encode(Fk:getSameGenerals(name))
end

local cardSubtypeStrings = {
  [Card.SubtypeNone] = "none",
  [Card.SubtypeDelayedTrick] = "delayed_trick",
  [Card.SubtypeWeapon] = "weapon",
  [Card.SubtypeArmor] = "armor",
  [Card.SubtypeDefensiveRide] = "defensive_horse",
  [Card.SubtypeOffensiveRide] = "offensive_horse",
  [Card.SubtypeTreasure] = "treasure",
}

function GetCardData(id)
  local card = Fk:getCardById(id)
  if card == nil then return json.encode{
    cid = id,
    known = false
  } end
  local ret = {
    cid = id,
    name = card.name,
    extension = card.package.extensionName,
    number = card.number,
    suit = card:getSuitString(),
    color = card.color,
    subtype = cardSubtypeStrings[card.sub_type]
  }
  if #card.skillNames > 0 then
    local orig = Fk:getCardById(id, true)
    ret.name = orig.name
    ret.virt_name = card.name
  end
  return json.encode(ret)
end

function GetAllGeneralPack()
  local ret = {}
  for _, name in ipairs(Fk.package_names) do
    if Fk.packages[name].type == Package.GeneralPack then
      table.insert(ret, name)
    end
  end
  return json.encode(ret)
end

function GetGenerals(pack_name)
  local ret = {}
  for _, g in ipairs(Fk.packages[pack_name].generals) do
    table.insert(ret, g.name)
  end
  return json.encode(ret)
end

function GetAllCardPack()
  local ret = {}
  for _, name in ipairs(Fk.package_names) do
    if Fk.packages[name].type == Package.CardPack then
      table.insert(ret, name)
    end
  end
  return json.encode(ret)
end

function GetCards(pack_name)
  local ret = {}
  for _, c in ipairs(Fk.packages[pack_name].cards) do
    table.insert(ret, c.id)
  end
  return json.encode(ret)
end

function GetCardSpecialSkills(cid)
  return json.encode(Fk:getCardById(cid).special_skills or {})
end

function DistanceTo(from, to)
  local a = ClientInstance:getPlayerById(from)
  local b = ClientInstance:getPlayerById(to)
  return a:distanceTo(b)
end

function GetPile(id, name)
  return json.encode(ClientInstance:getPlayerById(id):getPile(name) or {})
end

function GetAllPiles(id)
  return json.encode(ClientInstance:getPlayerById(id).special_cards or {})
end

---@param card string | integer
---@param player integer
function CanUseCard(card, player)
  local c   ---@type Card
  if type(card) == "number" then
    c = Fk:getCardById(card)
  else
    local data = json.decode(card)
    local skill = Fk.skills[data.skill]
    local selected_cards = data.subcards
    if skill:isInstanceOf(ViewAsSkill) then
      c = skill:viewAs(selected_cards)
      if not c then
        return "false"
      end
    else
      -- ActiveSkill should return true here
      return "true"
    end
  end

  local ret = c.skill:canUse(ClientInstance:getPlayerById(player), c)
  return json.encode(ret)
end

---@param card string | integer
---@param to_select integer @ id of the target
---@param selected integer[] @ ids of selected targets
function CanUseCardToTarget(card, to_select, selected)
  if ClientInstance:getPlayerById(to_select).dead then
    return "false"
  end
  local c   ---@type Card
  local selected_cards
  if type(card) == "number" then
    c = Fk:getCardById(card)
    selected_cards = {card}
  else
    local t = json.decode(card)
    return ActiveTargetFilter(t.skill, to_select, selected, t.subcards)
  end

  local ret = c.skill:targetFilter(to_select, selected, selected_cards, c)
  if ret then
    local r = Fk:currentRoom()
    local status_skills = r.status_skills[ProhibitSkill] or {}
    for _, skill in ipairs(status_skills) do
      if skill:isProhibited(Self, r:getPlayerById(to_select), c) then
        ret = false
        break
      end
    end
  end
  return json.encode(ret)
end

---@param card string | integer
---@param to_select integer @ id of a card not selected
---@param selected_targets integer[] @ ids of selected players
function CanSelectCardForSkill(card, to_select, selected_targets)
  local c   ---@type Card
  local selected_cards
  if type(card) == "number" then
    c = Fk:getCardById(card)
    selected_cards = {card}
  else
    error()
  end

  local ret = c.skill:cardFilter(to_select, selected_cards, selected_targets)
  return json.encode(ret)
end

---@param card string | integer
---@param selected_targets integer[] @ ids of selected players
function CardFeasible(card, selected_targets)
  local c   ---@type Card
  local selected_cards
  if type(card) == "number" then
    c = Fk:getCardById(card)
    selected_cards = {card}
  else
    local t = json.decode(card)
    return ActiveFeasible(t.skill, selected_targets, t.subcards)
  end

  local ret = c.skill:feasible(selected_targets, selected_cards, Self, c)
  return json.encode(ret)
end

-- Handle skills

function GetSkillData(skill_name)
  local skill = Fk.skills[skill_name]
  local freq = "notactive"
  if skill:isInstanceOf(ActiveSkill) or skill:isInstanceOf(ViewAsSkill) then
    freq = "active"
  end
  return json.encode{
    skill = Fk:translate(skill_name),
    orig_skill = skill_name,
    extension = skill.package.extensionName,
    freq = freq
  }
end

function ActiveCanUse(skill_name)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill then
    if skill:isInstanceOf(ActiveSkill) then
      ret = skill:canUse(Self)
    elseif skill:isInstanceOf(ViewAsSkill) then
      ret = skill:enabledAtPlay(Self)
      if ret then
        local exp = Exppattern:Parse(skill.pattern)
        local cnames = {}
        for _, m in ipairs(exp.matchers) do
          if m.name then table.insertTable(cnames, m.name) end
        end
        for _, n in ipairs(cnames) do
          local c = Fk:cloneCard(n)
          ret = c.skill:canUse(Self, c)
          if ret then break end
        end
      end
    end
  end
  return json.encode(ret)
end

function ActiveCardFilter(skill_name, to_select, selected, selected_targets)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill then
    if skill:isInstanceOf(ActiveSkill) then
      ret = skill:cardFilter(to_select, selected, selected_targets)
    elseif skill:isInstanceOf(ViewAsSkill) then
      ret = skill:cardFilter(to_select, selected)
    end
  end
  return json.encode(ret)
end

function ActiveTargetFilter(skill_name, to_select, selected, selected_cards)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill then
    if skill:isInstanceOf(ActiveSkill) then
      ret = skill:targetFilter(to_select, selected, selected_cards)
    elseif skill:isInstanceOf(ViewAsSkill) then
      local card = skill:viewAs(selected_cards)
      if card then
        ret = card.skill:targetFilter(to_select, selected, selected_cards)
      end
    end
  end
  return json.encode(ret)
end

function ActiveFeasible(skill_name, selected, selected_cards)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill then
    if skill:isInstanceOf(ActiveSkill) then
      ret = skill:feasible(selected, selected_cards, Self, nil)
    elseif skill:isInstanceOf(ViewAsSkill) then
      local card = skill:viewAs(selected_cards)
      if card then
        ret = card.skill:feasible(selected, selected_cards, Self, card)
      end
    end
  end
  return json.encode(ret)
end

function CanViewAs(skill_name, card_ids)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill then
    if skill:isInstanceOf(ViewAsSkill) then
      ret = skill:viewAs(card_ids) ~= nil
    elseif skill:isInstanceOf(ActiveSkill) then
      ret = true
    end
  end
  return json.encode(ret)
end

-- card_name may be id, name of card, or json string
function CardFitPattern(card_name, pattern)
  local exp = Exppattern:Parse(pattern)
  local c
  local ret = false
  if type(card_name) == "number" then
    c = Fk:getCardById(card_name)
    ret = exp:match(c)
  elseif string.sub(card_name, 1, 1) == "{" then
    local data = json.decode(card_name)
    local skill = Fk.skills[data.skill]
    local selected_cards = data.subcards
    if skill:isInstanceOf(ViewAsSkill) then
      c = skill:viewAs(selected_cards)
      if c then
        ret = exp:match(c)
      end
    else
      return "true"
    end
  else
    ret = exp:matchExp(card_name)
  end
  return json.encode(ret)
end

function SkillFitPattern(skill_name, pattern)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill and skill.pattern then
    local exp = Exppattern:Parse(pattern)
    ret = exp:matchExp(skill.pattern)
  end
  return json.encode(ret)
end

function SkillCanResponse(skill_name)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill and skill:isInstanceOf(ViewAsSkill) then
    ret = skill:enabledAtResponse(Self)
  end
  return json.encode(ret)
end

function GetVirtualEquip(player, cid)
  local c = ClientInstance:getPlayerById(player):getVirualEquip(cid)
  if not c then return "null" end
  return json.encode{
    name = c.name,
    cid = c.subcards[1],
  }
end

function GetExpandPileOfSkill(skillName)
  local skill = Fk.skills[skillName]
  return skill and (skill.expand_pile or "") or ""
end

function GetGameModes()
  local ret = {}
  for k, v in pairs(Fk.game_modes) do
    table.insert(ret, {
      name = Fk:translate(v.name),
      orig_name = v.name,
      minPlayer = v.minPlayer,
      maxPlayer = v.maxPlayer,
    })
  end
  table.sort(ret, function(a, b) return a.name > b.name end)
  return json.encode(ret)
end

dofile "lua/client/i18n/init.lua"
