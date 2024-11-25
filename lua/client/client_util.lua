-- SPDX-License-Identifier: GPL-3.0-or-later

-- All functions in this file are used by Qml

function Translate(src)
  return Fk:translate(src)
end

function GetGeneralData(name)
  local general = Fk.generals[name]
  if general == nil then general = Fk.generals["diaochan"] end
  return {
    package = general.package.name,
    extension = general.package.extensionName,
    kingdom = general.kingdom,
    subkingdom = general.subkingdom,
    hp = general.hp,
    maxHp = general.maxHp,
    mainMaxHpAdjustedValue = general.mainMaxHpAdjustedValue,
    deputyMaxHpAdjustedValue = general.deputyMaxHpAdjustedValue,
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
    mainMaxHp = general.mainMaxHpAdjustedValue,
    deputyMaxHp = general.deputyMaxHpAdjustedValue,
    gender = general.gender,
    skill = {},
    companions = general.companions
  }
  for _, s in ipairs(general.all_skills) do
    table.insert(ret.skill, {
      name = s[1],
      description = Fk:getDescription(s[1]),
      is_related_skill = s[2],
    })
  end
  for _, g in pairs(Fk.generals) do
    if table.contains(g.companions, general.name) then
      table.insertIfNeed(ret.companions, g.name)
    end
  end
  return ret
end

function GetSameGenerals(name)
  return Fk:getSameGenerals(name)
end

function IsCompanionWith(general, general2)
  local _general, _general2 = Fk.generals[general], Fk.generals[general2]
  return _general:isCompanionWith(_general2)
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
  if card == nil then return {
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
    subtype = cardSubtypeStrings[card.sub_type],
    -- known = Self:cardVisible(id)
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
  return ret
end

function GetCardExtensionByName(cardName)
  local card = Fk.all_card_types[cardName]
  return card and card.package.extensionName or ""
end

function GetAllMods()
  return Fk.extensions
end

function GetAllModNames()
  return Fk.extension_names
end

function GetAllGeneralPack()
  local ret = {}
  for _, name in ipairs(Fk.package_names) do
    if Fk.packages[name].type == Package.GeneralPack then
      table.insert(ret, name)
    end
  end
  return ret
end

function GetGenerals(pack_name)
  if not Fk.packages[pack_name] then return {} end
  local ret = {}
  for _, g in ipairs(Fk.packages[pack_name].generals) do
    if not g.total_hidden then
      table.insert(ret, g.name)
    end
  end
  return ret
end

function SearchAllGenerals(word)
  local ret = {}
  for _, name in ipairs(Fk.package_names) do
    if Fk.packages[name].type == Package.GeneralPack then
      table.insertTable(ret, SearchGenerals(name, word))
    end
  end
  return ret
end

function SearchGenerals(pack_name, word)
  local ret = {}
  if word == "" then return GetGenerals(pack_name) end
  for _, g in ipairs(Fk.packages[pack_name].generals) do
    if not g.total_hidden and string.find(Fk:translate(g.name), word) then
      table.insert(ret, g.name)
    end
  end
  return ret
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
  return ret
end

function GetCards(pack_name)
  local ret = {}
  for _, c in ipairs(Fk.packages[pack_name].cards) do
    table.insert(ret, c.id)
  end
  return ret
end

function GetCardSkill(cid)
  return Fk:getCardById(cid).skill and Fk:getCardById(cid).skill.name or ""
end

function GetCardSpecialSkills(cid)
  return Fk:getCardById(cid).special_skills or Util.DummyTable
end

function DistanceTo(from, to)
  local a = ClientInstance:getPlayerById(from)
  local b = ClientInstance:getPlayerById(to)
  return a:distanceTo(b)
end

function GetPile(id, name)
  return ClientInstance:getPlayerById(id):getPile(name) or Util.DummyTable
end

function GetAllPiles(id)
  return ClientInstance:getPlayerById(id).special_cards or Util.DummyTable
end

function GetPlayerSkills(id)
  local p = ClientInstance:getPlayerById(id)
  return table.map(p.player_skills, function(s)
    return s.visible and {
      name = s.name,
      description = Fk:getDescription(s.name),
    } or nil
  end)
end

-- Handle skills

function GetSkillData(skill_name)
  local skill = Fk.skills[skill_name]
  if not skill then return nil end
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
  return {
    skill = Fk:translate(skill_name),
    orig_skill = skill_name,
    extension = skill.package.extensionName,
    freq = freq,
    frequency = frequency,
    switchSkillName = skill.switchSkillName,
    isViewAsSkill = skill:isInstanceOf(ViewAsSkill),
  }
end

function GetSkillStatus(skill_name)
  local player = Self
  local skill = Fk.skills[skill_name]
  return {
    locked = not skill:isEffectable(player),
    times = skill:getTimes()
  }
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
      return true
    end
  else
    ret = exp:matchExp(card_name)
  end
  return ret
end

function GetVirtualEquip(player, cid)
  local c = ClientInstance:getPlayerById(player):getVirualEquip(cid)
  if not c then return nil end
  return {
    name = c.name,
    cid = c.subcards[1],
  }
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
  return ret
end

function GetPlayerHandcards(pid)
  local c = ClientInstance
  local p = c:getPlayerById(pid)
  return p and p.player_cards[Player.Hand] or ""
end

function GetPlayerEquips(pid)
  local c = ClientInstance
  local p = c:getPlayerById(pid)
  return p.player_cards[Player.Equip]
end

function ResetClientLua()
  local self = ClientInstance
  local _data = self.enter_room_data;
  local data = self.settings
  Self = ClientPlayer:new(self.client:getSelf())
  self:initialize(self.client) -- clear old client data
  self.players = {Self}
  self.alive_players = {Self}
  self.discard_pile = {}

  self.enter_room_data = _data;
  self.settings = data

  self.disabled_packs = data.disabledPack
  self.disabled_generals = data.disabledGenerals
  -- ClientInstance:notifyUI("EnterRoom", jsonData)
end

function ResetAddPlayer(j)
  fk.client_callback["AddPlayer"](ClientInstance, j)
end

function GetRoomConfig()
  return ClientInstance.settings
end

function GetPlayerGameData(pid)
  local c = ClientInstance
  local p = c:getPlayerById(pid)
  if not p then return {0, 0, 0, 0} end
  local raw = p.player:getGameData()
  local ret = {}
  for _, i in fk.qlist(raw) do
    table.insert(ret, i)
  end
  table.insert(ret, p.player:getTotalGameTime())
  return ret
end

function SetPlayerGameData(pid, data)
  local c = ClientInstance
  local p = c:getPlayerById(pid)
  local total, win, run = table.unpack(data)
  p.player:setGameData(total, win, run)
  table.insert(data, 1, pid)
  ClientInstance:notifyUI("UpdateGameData", data)
end

function FilterMyHandcards()
  Self:filterHandcards()
end

function SetObserving(o)
  ClientInstance.observing = o
end

function SetReplaying(o)
  ClientInstance.replaying = o
end

function SetReplayingShowCards(o)
  ClientInstance.replaying_show = o
  if o then
    for _, p in ipairs(ClientInstance.players) do
      ClientInstance:notifyUI("PropertyUpdate", { p.id, "role_shown", true })
    end
  end
end

function CheckSurrenderAvailable(playedTime)
  local curMode = ClientInstance.settings.gameMode
  return Fk.game_modes[curMode]:surrenderFunc(playedTime)
end

function SaveRecord()
  local c = ClientInstance
  c.client:saveRecord(json.encode(c.record), c.record[2])
end

function GetCardProhibitReason(cid)
  local card = Fk:getCardById(cid)
  if not card then return "" end
  local handler = ClientInstance.current_request_handler
  if (not handler) or (not handler:isInstanceOf(Fk.request_handlers["AskForUseActiveSkill"])) then return "" end
  local method, pattern = "", handler.pattern or "."

  if handler.class.name == "ReqPlayCard" then method = "play"
  elseif handler.class.name == "ReqResponseCard" then method = "response"
  elseif handler.class.name == "ReqUseCard" then method = "use"
  elseif handler.skill_name == "discard_skill" then method = "discard"
  end

  if method == "play" and not card.skill:canUse(Self, card) then return "" end
  if method ~= "play" and not card:matchPattern(pattern) then return "" end
  if method == "play" then method = "use" end

  local fn_table = {
    use = "prohibitUse",
    response = "prohibitResponse",
    discard = "prohibitDiscard",
  }
  local str_table = {
    use = "method_use",
    response = "method_response_play",
    discard = "method_discard",
  }
  if not fn_table[method] then return "" end

  local status_skills = Fk:currentRoom().status_skills[ProhibitSkill] or Util.DummyTable
  local s
  for _, skill in ipairs(status_skills) do
    local fn = skill[fn_table[method]]
    if fn(skill, Self, card) then
      s = skill
      break
    end
  end
  if not s then return "" end

  -- try to return a translated string
  local skillName = s.name
  local ret = Fk:translate(skillName)
  if ret ~= skillName then
    return ret .. Fk:translate("prohibit") .. Fk:translate(str_table[method])
  elseif skillName:endsWith("_prohibit") and skillName:startsWith("#") then
    return Fk:translate(skillName:sub(2, -10)) .. Fk:translate("prohibit") .. Fk:translate(str_table[method])
  else
    return ret
  end
end

function GetTargetTip(pid)
  local handler = ClientInstance.current_request_handler --[[@as ReqPlayCard ]]
  if (not handler) or (not handler:isInstanceOf(Fk.request_handlers["AskForUseActiveSkill"])) then return "" end

  local to_select = pid
  local selected = handler.selected_targets
  local selected_cards = handler.pendings
  local card = handler.selected_card --[[@as Card?]]
  local skill = Fk.skills[handler.skill_name]
  local photo = handler.scene.items["Photo"][pid] --[[@as Photo]]
  if not photo then return {} end
  local selectable = photo.enabled
  local extra_data = handler.extra_data

  local ret = {}

  if skill then
    if skill:isInstanceOf(ActiveSkill) then
      local tip = skill:targetTip(to_select, selected, selected_cards, nil, selectable, extra_data)
      if type(tip) == "string" then
        table.insert(ret, { content = tip, type = "normal" })
      elseif type(tip) == "table" then
        table.insertTable(ret, tip)
      end
    elseif skill:isInstanceOf(ViewAsSkill) then
      card = skill:viewAs(selected_cards)
    end
  end

  if card then
    local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable
    for _, sk in ipairs(status_skills) do
      ret = ret or {}
      if #ret > 4 then
        return ret
      end

      local tip = sk:getTargetTip(Self, to_select, selected, selected_cards, card, selectable, extra_data)
      if type(tip) == "string" then
        table.insert(ret, { content = tip, type = "normal" })
      elseif type(tip) == "table" then
        table.insertTable(ret, tip)
      end
    end

    ret = ret or {}
    local tip = card.skill:targetTip(to_select, selected, selected_cards, card, selectable, extra_data)
    if type(tip) == "string" then
      table.insert(ret, { content = tip, type = "normal" })
    elseif type(tip) == "table" then
      table.insertTable(ret, tip)
    end
  end

  return ret
end

function CanSortHandcards(pid)
  return ClientInstance:getPlayerById(pid):getMark(MarkEnum.SortProhibited) == 0
end

function PoxiPrompt(poxi_type, data, extra_data)
  local poxi = Fk.poxi_methods[poxi_type]
  if not poxi or not poxi.prompt then return "" end
  if type(poxi.prompt) == "string" then return Fk:translate(poxi.prompt) end
  return Fk:translate(poxi.prompt(data, extra_data))
end

function PoxiFilter(poxi_type, to_select, selected, data, extra_data)
  local poxi = Fk.poxi_methods[poxi_type]
  if not poxi then return false end
  return poxi.card_filter(to_select, selected, data, extra_data)
end

function PoxiFeasible(poxi_type, selected, data, extra_data)
  local poxi = Fk.poxi_methods[poxi_type]
  if not poxi then return false end
  return poxi.feasible(selected, data, extra_data)
end

function GetQmlMark(mtype, name, value, p)
  local spec = Fk.qml_marks[mtype]
  if not spec then return {} end
  p = ClientInstance:getPlayerById(p)
  value = json.decode(value)
  return {
    qml_path = type(spec.qml_path) == "function" and spec.qml_path(name, value, p) or spec.qml_path,
    text = spec.how_to_show(name, value, p)
  }
end

function GetMiniGame(gtype, p, data)
  local spec = Fk.mini_games[gtype]
  p = ClientInstance:getPlayerById(p)
  data = json.decode(data)
  return {
    qml_path = type(spec.qml_path) == "function" and spec.qml_path(p, data) or spec.qml_path,
  }
end

function ReloadPackage(path)
  Fk:reloadPackage(path)
end

function GetPendingSkill()
  local h = ClientInstance.current_request_handler
  local reqActive = Fk.request_handlers["AskForUseActiveSkill"]
  return h and h:isInstanceOf(reqActive) and
    (h.selected_card == nil and h.skill_name) or ""
end

function RevertSelection()
  local h = ClientInstance.current_request_handler ---@type ReqActiveSkill
  local reqActive = Fk.request_handlers["AskForUseActiveSkill"]
  if not (h and h:isInstanceOf(reqActive) and h.pendings) then return end
  h.change = {}
  -- 1. 取消选中所有已选 2. 尝试选中所有之前未选的牌
  local unselectData = { selected = false }
  local selectData = { selected = true }
  local to_select = {}
  local lastcid
  local lastselected = false
  for cid, cardItem in pairs(h.scene:getAllItems("CardItem")) do
    if table.contains(h.pendings, cid) then
      lastcid = cid
      h:selectCard(cid, unselectData)
    else
      table.insert(to_select, cardItem)
    end
  end
  for _, cardItem in ipairs(to_select) do
    if cardItem.enabled then
      lastcid = cardItem.id
      lastselected = true
      h:selectCard(cardItem.id, selectData)
    end
  end
  -- 最后模拟一次真实点击卡牌以更新目标和按钮状态
  if lastcid then
    h:selectCard(lastcid, { selected = not lastselected })
    h:update("CardItem", lastcid, "click", { selected = lastselected })
  end
  h.scene:notifyUI()
end

local requestUIUpdating = false
function UpdateRequestUI(elemType, id, action, data)
  if requestUIUpdating then return end
  requestUIUpdating = true
  local h = ClientInstance.current_request_handler
  if not h then
    requestUIUpdating = false
    return
  end
  h.change = {}
  local finish = h:update(elemType, id, action, data)
  if not finish then
    h.scene:notifyUI()
  else
    h:_finish()
  end
  requestUIUpdating = false
end

function FinishRequestUI()
  local h = ClientInstance.current_request_handler
  if h then
    h:_finish()
    ClientInstance.current_request_handler = nil
  end
end

function CardVisibility(cardId)
  local player = Self
  local card = Fk:getCardById(cardId)
  if not card then return false end
  return player:cardVisible(cardId)
end

function RoleVisibility(targetId)
  local player = Self
  local target = ClientInstance:getPlayerById(targetId)
  if not target then return false end
  return player:roleVisible(target)
end

function IsMyBuddy(me, other)
  local from = ClientInstance:getPlayerById(me)
  local to = ClientInstance:getPlayerById(other)
  return from and to and from:isBuddy(to)
end

-- special_name 为nil时是手牌
function HasVisibleCard(me, other, special_name)
  local from = ClientInstance:getPlayerById(me)
  local to = ClientInstance:getPlayerById(other)
  if not (from and to) then return false end
  local ids
  if not special_name then ids = to:getCardIds("h")
  else ids = to:getPile(special_name) end

  for _, id in ipairs(ids) do
    if from:cardVisible(id) then
      return true
    end
  end
  return false
end

function RefreshStatusSkills()
  local self = ClientInstance
  if not self.recording then return end -- 在回放录像就别刷了
  -- 刷所有人手牌上限
  for _, p in ipairs(self.alive_players) do
    self:notifyUI("MaxCard", {
      pcardMax = p:getMaxCards(),
      id = p.id,
    })
  end
  -- 刷自己的手牌
  for _, cid in ipairs(Self:getCardIds("h")) do
    self:notifyUI("UpdateCard", cid)
  end
  -- 刷技能状态
  self:notifyUI("UpdateSkill", nil)
end

dofile "lua/client/i18n/init.lua"
