-- SPDX-License-Identifier: GPL-3.0-or-later

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
    subkingdom = general.subkingdom,
    hp = general.hp,
    maxHp = general.maxHp,
    shield = general.shield,
    hidden = general.hidden,
    total_hidden = general.total_hidden,
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
    gender = general.gender,
    skill = {},
    related_skill = {},
    companions = general.companions
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
  for _, s in ipairs(general.related_skills) do
    table.insert(ret.related_skill, {
      name = s.name,
      description = Fk:getDescription(s.name)
    })
  end
  for _, s in ipairs(general.related_other_skills) do
    table.insert(ret.related_skill, {
      name = s,
      description = Fk:getDescription(s)
    })
  end
  for _, g in pairs(Fk.generals) do
    if table.contains(g.companions, general.name) then
      table.insertIfNeed(ret.companions, g.name)
    end
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

function GetCardData(id, virtualCardForm)
  local card = Fk:getCardById(id)
  if card == nil then return json.encode{
    cid = id,
    known = false
  } end
  local mark = {}
  for k, v in pairs(card.mark) do
    if k and k:startsWith("@") and v and v ~= 0 then
      table.insert(mark, {
        k = k, v = v,
      })
    end
  end
  local ret = {
    cid = id,
    name = card.name,
    extension = card.package.extensionName,
    number = card.number,
    suit = card:getSuitString(),
    color = card:getColorString(),
    mark = mark,
    type = card.type,
    subtype = cardSubtypeStrings[card.sub_type]
  }
  if card.skillName ~= "" then
    local orig = Fk:getCardById(id, true)
    ret.name = orig.name
    ret.virt_name = card.name
  end
  if virtualCardForm then
    local virtualCard = ClientInstance:getPlayerById(virtualCardForm):getVirualEquip(id)
    if virtualCard then
      ret.virt_name = virtualCard.name
      ret.subtype = cardSubtypeStrings[virtualCard.sub_type]
    end
  end
  return json.encode(ret)
end

function GetCardExtensionByName(cardName)
  local card = table.find(Fk.cards, function(card)
    return card.name == cardName
  end)

  return card and card.package.extensionName or ""
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
    if not g.total_hidden then
      table.insert(ret, g.name)
    end
  end
  return json.encode(ret)
end

function SearchAllGenerals(word)
  local ret = {}
  for _, name in ipairs(Fk.package_names) do
    if Fk.packages[name].type == Package.GeneralPack then
      table.insertTable(ret, json.decode(SearchGenerals(name, word)))
    end
  end
  return json.encode(ret)
end

function SearchGenerals(pack_name, word)
  local ret = {}
  if word == "" then return GetGenerals(pack_name) end
  for _, g in ipairs(Fk.packages[pack_name].generals) do
    if not g.total_hidden and string.find(Fk:translate(g.name), word) then
      table.insert(ret, g.name)
    end
  end
  return json.encode(ret)
end

function UpdatePackageEnable(pkg, enabled)
  if enabled then
    table.removeOne(ClientInstance.disabled_packs, pkg)
  else
    table.insertIfNeed(ClientInstance.disabled_packs, pkg)
  end
end

function GetAvailableGeneralsNum()
  local generalPool = Fk:getAllGenerals()
  local except = {}
  local ret = 0
  for _, g in ipairs(Fk.packages["test_p_0"].generals) do
    table.insert(except, g.name)
  end

  local availableGenerals = {}
  for _, general in pairs(generalPool) do
    if not table.contains(except, general.name) then
      if (not general.hidden and not general.total_hidden) and
        #table.filter(availableGenerals, function(g)
        return g.trueName == general.trueName
      end) == 0 then
        ret = ret + 1
      end
    end
  end

  return ret
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
  return json.encode(Fk:getCardById(cid).special_skills or Util.DummyTable)
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
  return json.encode(ClientInstance:getPlayerById(id).special_cards or Util.DummyTable)
end

function GetPlayerSkills(id)
  local p = ClientInstance:getPlayerById(id)
  return json.encode(table.map(p.player_skills, function(s)
    return s.visible and {
      name = s.name,
      description = Fk:getDescription(s.name),
    } or nil
  end))
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

  player = ClientInstance:getPlayerById(player)
  local ret = c.skill:canUse(player, c)
  ret = ret and not player:prohibitUse(c)
  if ret then
    local min_target = c.skill:getMinTargetNum()
    if min_target > 0 then
      for _, p in ipairs(ClientInstance.players) do
        if c.skill:targetFilter(p.id, {}, {}, c) then
          return "true"
        end
      end
      return "false"
    end
  end
  return json.encode(ret)
end

function CardProhibitedUse(card)
  local c   ---@type Card
  local ret = false
  if type(card) == "number" then
    c = Fk:getCardById(card)
  else
    local data = json.decode(card)
    local skill = Fk.skills[data.skill]
    local selected_cards = data.subcards
    if skill:isInstanceOf(ViewAsSkill) then
      c = skill:viewAs(selected_cards)
    end
  end
  if c == nil then
    return "true"
  else
    ret = Self:prohibitUse(c)
  end
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
  ret = ret and not Self:isProhibited(Fk:currentRoom():getPlayerById(to_select), c)
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
  if not skill then return "null" end
  local freq = "notactive"
  if skill:isInstanceOf(ActiveSkill) or skill:isInstanceOf(ViewAsSkill) then
    freq = "active"
  end
  local frequency
  if skill.frequency == Skill.Limited then
    frequency = "limit"
  elseif skill.frequency == Skill.Wake then
    frequency = "wake"
  elseif skill.frequency == Skill.Quest then
    frequency = "quest"
  end
  return json.encode{
    skill = Fk:translate(skill_name),
    orig_skill = skill_name,
    extension = skill.package.extensionName,
    freq = freq,
    frequency = frequency,
    switchSkillName = skill.switchSkillName,
    isViewAsSkill = skill:isInstanceOf(ViewAsSkill),
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
          if m.name then
            table.insertTable(cnames, m.name)
          end
          if m.trueName then
            table.insertTable(cnames, m.trueName)
          end
        end
        for _, n in ipairs(cnames) do
          local c = Fk:cloneCard(n)
          c.skillName = skill_name
          ret = c.skill:canUse(Self, c)
          if ret then break end
        end
      end
    end
  end
  return json.encode(ret)
end

function ActiveSkillPrompt(skill_name, selected, selected_targets)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill then
    if type(skill.prompt) == "function" then
      ret = skill:prompt(selected, selected_targets)
    else
      ret = skill.prompt
    end
  end
  return json.encode(ret or "")
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
        ret = card.skill:targetFilter(to_select, selected, selected_cards, card)
        ret = ret and not Self:isProhibited(Fk:currentRoom():getPlayerById(to_select), card)
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

function CardProhibitedResponse(card)
  local c   ---@type Card
  local ret = false
  if type(card) == "number" then
    c = Fk:getCardById(card)
  else
    local data = json.decode(card)
    local skill = Fk.skills[data.skill]
    local selected_cards = data.subcards
    if skill:isInstanceOf(ViewAsSkill) then
      c = skill:viewAs(selected_cards)
    end
  end
  if c == nil then
    return "true"
  else
    ret = Self:prohibitUse(c)
  end
  return json.encode(ret)
end

function SkillCanResponse(skill_name, cardResponsing)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill and skill:isInstanceOf(ViewAsSkill) then
    ret = skill:enabledAtResponse(Self, cardResponsing)
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

function GetInteractionOfSkill(skill_name)
  local skill = Fk.skills[skill_name]
  if skill and skill.interaction then
    return json.encode(skill:interaction())
  end
  return "null"
end

function SetInteractionDataOfSkill(skill_name, data)
  local skill = Fk.skills[skill_name]
  if skill and skill.interaction then
    skill.interaction.data = json.decode(data)
  end
end

function ChangeSelf(pid)
  local c = ClientInstance
  c.client:changeSelf(pid) -- for qml
  Self = c:getPlayerById(pid)
end

function GetPlayerHandcards(pid)
  local c = ClientInstance
  local p = c:getPlayerById(pid)
  return json.encode(p.player_cards[Player.Hand])
end

function GetPlayerEquips(pid)
  local c = ClientInstance
  local p = c:getPlayerById(pid)
  return json.encode(p.player_cards[Player.Equip])
end

function ResetClientLua()
  local _data = ClientInstance.enter_room_data;
  local data = ClientInstance.room_settings
  Self = ClientPlayer:new(fk.Self)
  ClientInstance = Client:new() -- clear old client data
  ClientInstance.players = {Self}
  ClientInstance.alive_players = {Self}
  ClientInstance.discard_pile = {}

  ClientInstance.enter_room_data = _data;
  ClientInstance.room_settings = data

  ClientInstance.disabled_packs = data.disabledPack
  ClientInstance.disabled_generals = data.disabledGenerals
  -- ClientInstance:notifyUI("EnterRoom", jsonData)
end

function ResetAddPlayer(j)
  fk.client_callback["AddPlayer"](j)
end

function GetRoomConfig()
  return json.encode(ClientInstance.room_settings)
end

function GetPlayerGameData(pid)
  local c = ClientInstance
  local p = c:getPlayerById(pid)
  if not p then return "[0, 0, 0]" end
  local raw = p.player:getGameData()
  local ret = {}
  for _, i in fk.qlist(raw) do
    table.insert(ret, i)
  end
  return json.encode(ret)
end

function SetPlayerGameData(pid, data)
  local c = ClientInstance
  local p = c:getPlayerById(pid)
  p.player:setGameData(table.unpack(data))
  table.insert(data, 1, pid)
  ClientInstance:notifyUI("UpdateGameData", json.encode(data))
end

function FilterMyHandcards()
  Self:filterHandcards()
end

function SetObserving(o)
  ClientInstance.observing = o
end

function CheckSurrenderAvailable(playedTime)
  local curMode = ClientInstance.room_settings.gameMode
  return json.encode(Fk.game_modes[curMode]:surrenderFunc(playedTime))
end

function SaveRecord()
  local c = ClientInstance
  c.client:saveRecord(json.encode(c.record), c.record[2])
end

dofile "lua/client/i18n/init.lua"
