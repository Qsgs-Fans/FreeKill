-- SPDX-License-Identifier: GPL-3.0-or-later

local baseGameLogic = require "server.gamelogic"

---@class GameLogic: Base.GameLogic --, GameLogicLegacyMixin
---@field public role_table string[][]
local GameLogic = baseGameLogic:subclass("GameLogic")

function GameLogic:initialize(room)
  baseGameLogic.initialize(self, room)

  self.role_table = {
    { "lord" },
    { "lord", "rebel" },
    { "lord", "rebel", "renegade" },
    { "lord", "loyalist", "rebel", "renegade" },
    { "lord", "loyalist", "rebel", "rebel", "renegade" },
    { "lord", "loyalist", "rebel", "rebel", "rebel", "renegade" },
    { "lord", "loyalist", "loyalist", "rebel", "rebel", "rebel", "renegade" },
    { "lord", "loyalist", "loyalist", "rebel", "rebel", "rebel", "rebel", "renegade" },

    -- 意义何在
    {
      "lord", "loyalist", "loyalist", "loyalist",
      "rebel", "rebel", "rebel", "rebel", "renegade"
    },
    {
      "lord", "loyalist", "loyalist", "loyalist",
      "rebel", "rebel", "rebel", "rebel", "rebel", "renegade"
    },
    {
      "lord", "loyalist", "loyalist", "loyalist", "loyalist",
      "rebel", "rebel", "rebel", "rebel", "rebel", "renegade"
    },
    {
      "lord", "loyalist", "loyalist", "loyalist", "loyalist",
      "rebel", "rebel", "rebel", "rebel", "rebel", "rebel", "renegade"
    },
  }
end

function GameLogic:run()
  -- default logic
  local room = self.room
  table.shuffle(room.players)
  self:assignRoles()
  self:adjustSeats()
  self:chooseGenerals()

  self:buildPlayerCircle()
  self:broadcastGeneral()
  self:prepareDrawPile()
  self:attachSkillToPlayers()
  self:prepareForStart()

  self:action()
end

---@return boolean
local function execGameEvent(tp, ...)
  local event = tp:create(...)
  local _, ret = event:exec()
  return ret
end

--- 分配身份
function GameLogic:assignRoles()
  local room = self.room
  local n = #room.players
  local roles = self.role_table[n]
  table.shuffle(roles)

  for i = 1, n do
    local p = room.players[i]
    p.role = roles[i]
    if p.role == "lord" then
      room:setPlayerProperty(p, "role_shown", true)
    end
    room:broadcastProperty(p, "role")
  end
end

--- 进行选将
function GameLogic:chooseGenerals()
  local room = self.room
  local generalNum = room:getSettings('generalNum')
  local n = room:getSettings('enableDeputy') and 2 or 1
  local lord = room:getLord()
  local lord_generals = {}

  if lord ~= nil then
    room:setCurrent(lord)
    local generals = room:getNGenerals(generalNum)
    lord_generals = room:askToChooseGeneral(lord, { generals = generals, n = n })
    local lord_general, deputy
    if type(lord_generals) == "table" then
      deputy = lord_generals[2]
      lord_general = lord_generals[1]
    else
      lord_general = lord_generals
      lord_generals = {lord_general}
    end

    generals = table.filter(generals, function(g) return not table.contains(lord_generals, g) end)
    room:returnToGeneralPile(generals)

    room:prepareGeneral(lord, lord_general, deputy, true)

    room:askToChooseKingdom({lord})
  end

  local nonlord = room:getOtherPlayers(lord, true)
  local generals = table.random(room.general_pile, #nonlord * generalNum)

  local req = Request:new(nonlord, "AskForGeneral")
  req.timeout = self.room:getSettings('generalTimeout')
  for i, p in ipairs(nonlord) do
    local arg = table.slice(generals, (i - 1) * generalNum + 1, i * generalNum + 1)
    req:setData(p, { arg, n })
    req:setDefaultReply(p, table.random(arg, n))
  end

  for _, p in ipairs(nonlord) do
    local result = req:getResult(p)
    local general, deputy = result[1], result[2]
    room:prepareGeneral(p, general, deputy)
  end

  room:askToChooseKingdom(nonlord)
end

function GameLogic:buildPlayerCircle()
  local room = self.room
  local players = room.players
  room.alive_players = {table.unpack(players)}
  for i = 1, #players - 1 do
    players[i].next = players[i + 1]
  end
  players[#players].next = players[1]
end

--- 公布武将
function GameLogic:broadcastGeneral()
  local room = self.room
  local players = room.players

  for _, p in ipairs(players) do
    assert(p.general ~= "")
    local general = Fk.generals[p.general]
    local deputy = Fk.generals[p.deputyGeneral]
    p.maxHp = p:getGeneralMaxHp()
    p.hp = deputy and math.floor((deputy.hp + general.hp) / 2) or general.hp
    p.shield = math.min(general.shield + (deputy and deputy.shield or 0), 5)
    -- TODO: setup AI here

    local changer = Fk.game_modes[room:getSettings('gameMode')]:getAdjustedProperty(p)
    if changer then
      for key, value in pairs(changer) do
        p[key] = value
      end
    end
    local fixMaxHp = Fk.generals[p.general].fixMaxHp
    local deputyFix = Fk.generals[p.deputyGeneral] and Fk.generals[p.deputyGeneral].fixMaxHp
    if deputyFix then
      fixMaxHp = fixMaxHp and math.min(fixMaxHp, deputyFix) or deputyFix
    end
    if fixMaxHp then
      p.maxHp = fixMaxHp
    end
    p.hp = math.min(p.maxHp, p.hp)

    room:broadcastProperty(p, "general")
    room:broadcastProperty(p, "deputyGeneral")
    room:broadcastProperty(p, "kingdom")
    room:broadcastProperty(p, "maxHp")
    room:broadcastProperty(p, "hp")
    room:broadcastProperty(p, "shield")
  end
end

function GameLogic:prepareDrawPile()
  local room = self.room
  room:prepareDrawPile()
  room:doBroadcastNotify("PrepareDrawPile", room.draw_pile)
end

function GameLogic:attachSkillToPlayers()
  local room = self.room

  local addRoleModSkills = function(player, skillName)
    local skill = Fk.skills[skillName]
    if not skill then
      fk.qCritical("Skill: "..skillName.." doesn't exist!")
      return
    end
    if skill:hasTag(Skill.Lord) and not (player.role == "lord" and player.role_shown and room:isGameMode("role_mode")) then
      return
    end

    if skill:hasTag(Skill.AttachedKingdom) and not table.contains(skill:getSkeleton().attached_kingdom, player.kingdom) then
      return
    end

    room:handleAddLoseSkills(player, skillName, nil, false, true)
    self:trigger(fk.EventAcquireSkill, player, {skill = skill, who = player})
  end
  for _, p in ipairs(room.alive_players) do
    local skills = Fk.generals[p.general]:getSkillNameList(true)
    for _, s in ipairs(skills) do
      addRoleModSkills(p, s)
    end

    local deputy = Fk.generals[p.deputyGeneral]
    if deputy then
      skills = deputy:getSkillNameList(true)
      for _, s in ipairs(skills) do
        addRoleModSkills(p, s)
      end
    end
  end
end

function GameLogic:prepareForStart()
  local room = self.room
  local players = room.players

  --记录初始武将以用于正确胜率统计
  local record = {}
  for _, p in ipairs(players) do
    local id, general, deputyGeneral = p.id, p.general, p.deputyGeneral

    --隐匿
    if p:getMark("__hidden_general") ~= 0 then
      general = p:getMark("__hidden_general")
    end
    if p:getMark("__hidden_deputy") ~= 0 then
      deputyGeneral = p:getMark("__hidden_deputy")
    end

    --国战
    if p:getMark("__heg_general") ~= 0 then
      general = p:getMark("__heg_general")
    end
    if p:getMark("__heg_deputy") ~= 0 then
      deputyGeneral = p:getMark("__heg_deputy")
    end

    table.insert(record, {id, general, deputyGeneral})
  end
  room:setBanner("InitialGeneral", record)

  self:addTriggerSkill(Fk.skills["game_rule"] --[[@as TriggerSkill]])
  for _, trig in ipairs(Fk.global_trigger) do
    self:addTriggerSkill(trig)
  end

  room:sendLog{ type = "$GameStart", arg = room:getSettings('gameMode') }
end

function GameLogic:action()
  self:trigger(fk.GamePrepared)
  local room = self.room

  execGameEvent(GameEvent.DrawInitial)

  while true do
    execGameEvent(GameEvent.Round)
    if room.game_finished then break end
    if table.every(room.players, function(p) return p.dead and p.rest == 0 end) then room:gameOver("") end
    room:setCurrent(room.players[1])
  end
end

--- 获取实际的伤害事件
---@param n integer @ 最多找多少个
---@param func fun(e: GameEvent.Damage): boolean? @ 过滤用的函数
---@param scope? integer @ 查询历史范围，只能是当前阶段/回合/轮次
---@param end_id? integer @ 查询历史范围：从最后的事件开始逆序查找直到id为end_id的事件（不含）
---@return GameEvent.Damage[] @ 找到的符合条件的所有事件，最多n个但不保证有n个
function GameLogic:getActualDamageEvents(n, func, scope, end_id)
  if not end_id then
    scope = scope or Player.HistoryTurn
  end

  n = n or 1
  func = func or Util.TrueFunc

  local eventType = GameEvent.Damage
  local ret = {}
  local endIdRecorded
  local tempEvents = {}

  local addTempEvents = function(reverse)
    if #tempEvents > 0 and #ret < n then
      table.sort(tempEvents, function(a, b)
        if reverse then
          return a.data.dealtRecorderId > b.data.dealtRecorderId
        else
          return a.data.dealtRecorderId < b.data.dealtRecorderId
        end
      end)

      for _, e in ipairs(tempEvents) do
        table.insert(ret, e)
        if #ret >= n then return true end
      end
    end

    endIdRecorded = nil
    tempEvents = {}

    return false
  end

  if scope then
    local event = self:getCurrentEvent()
    local start_event ---@type GameEvent?
    if scope == Player.HistoryGame then
      start_event = self.all_game_events[1]
    elseif scope == Player.HistoryRound then
      start_event = event:findParent(GameEvent.Round, true)
    elseif scope == Player.HistoryTurn then
      start_event = event:findParent(GameEvent.Turn, true)
    elseif scope == Player.HistoryPhase then
      start_event = event:findParent(GameEvent.Phase, true)
    end

    if not start_event then return {} end

    local events = self.event_recorder[eventType] or Util.DummyTable ---@type GameEvent.Damage[]
    local from = start_event.id
    local to = start_event.end_id
    if math.abs(to) == 1 then to = #self.all_game_events end

    for _, v in ipairs(events) do
      local damageData = v.data
      if damageData.dealtRecorderId then
        if endIdRecorded and v.id > endIdRecorded then
          local result = addTempEvents()
          if result then
            return ret
          end
        end

        if v.id >= from and v.id <= to then
          if not endIdRecorded and v.end_id > -1 and v.end_id > v.id then
            endIdRecorded = v.end_id
          end

          if func(v) then
            if endIdRecorded then
              table.insert(tempEvents, v)
            else
              table.insert(ret, v)
            end
          end
        end
        if #ret >= n then break end
      end
    end

    addTempEvents()
  else
    local events = self.event_recorder[eventType] or Util.DummyTable ---@type GameEvent.Damage[]

    for i = #events, 1, -1 do
      local e = events[i]
      if e.id <= end_id then break end

      local damageData = e.data
      if damageData.dealtRecorderId then
        if e.end_id == -1 or (endIdRecorded and endIdRecorded > e.end_id) then
          local result = addTempEvents(true)
          if result then
            return ret
          end

          if func(e) then
            table.insert(ret, e)
          end
        else
          endIdRecorded = e.end_id
          if func(e) then
            table.insert(tempEvents, e)
          end
        end

        if #ret >= n then break end
      end
    end

    addTempEvents(true)
  end

  return ret
end

--检测最近的伤害事件是否由执行牌的效果触发，即通常描述的使用牌对目标角色造成伤害
---@param is_exact boolean? @ 是否进一步判定使用者和来源是否一致（默认为true）
---@return boolean?
function GameLogic:damageByCardEffect(is_exact)
  is_exact = (is_exact == nil) and true or is_exact
  local d_event = self:getCurrentEvent():findParent(GameEvent.Damage, true)
  if d_event == nil then return false end
  local damage = d_event.data
  if damage.chain or damage.card == nil then return false end
  local c_event = d_event:findParent(GameEvent.CardEffect, false, 2)
  if c_event == nil then return false end
  local effect = c_event.data
  return damage.card == effect.card and
  (not is_exact or (damage.from or {}) == effect.from)
end

--判定一些卡牌在此次移动事件发生之后没有再被移动过。根据规则集，如果需要在卡牌移动后对参与此事件的卡牌进行操作，是需要过一遍这个检测的（注意：由于洗牌的存在，若判定处在弃牌堆的卡牌需要手动判区域）
---@param cards integer[] @ 待判定的卡牌
---@param end_id? integer @ 查询历史范围：从最后的事件开始逆序查找直到id为end_id的事件（不含），缺省值为当前移动事件的id
---@return integer[] @ 返回满足条件的卡牌的id列表
function GameLogic:moveCardsHoldingAreaCheck(cards, end_id)
  if #cards == 0 then return {} end
  if end_id == nil then
    local move_event = self:getCurrentEvent():findParent(GameEvent.MoveCards, true)
    if move_event == nil then return {} end
    end_id = move_event.id
  end
  local ret = table.simpleClone(cards)
  self:getEventsByRule(GameEvent.MoveCards, 1, function (e)
    for _, move in ipairs(e.data) do
      for _, info in ipairs(move.moveInfo) do
        table.removeOne(ret, info.cardId)
      end
    end
    return (#ret == 0)
  end, end_id)
  return ret
end


function GameLogic:breakTurn()
  local event = self:getCurrentEvent():findParent(GameEvent.Turn)
  if not event then return end
  event:shutdown()
end

return GameLogic
