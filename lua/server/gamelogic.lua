-- SPDX-License-Identifier: GPL-3.0-or-later

---@class GameLogic: Object --, GameLogicLegacyMixin
---@field public room Room
---@field public skill_table table<(TriggerEvent|integer|string), TriggerSkill[]>
---@field public skill_priority_table table<(TriggerEvent|integer|string), number[]>
---@field public skills string[]
---@field public game_event_stack Stack
---@field public cleaner_stack Stack
---@field public role_table string[][]
---@field public all_game_events GameEvent[]
---@field public event_recorder table<GameEvent, GameEvent>
---@field public current_event_id integer
---@field public current_trigger_event_id integer
local GameLogic = class("GameLogic")

function GameLogic:initialize(room)
  self.room = room

  self.skills = {}
  self.skill_table = {}
  self.skill_priority_table = {}
  -- 牢技能
  self.legacy_skill_table = {}   -- TriggerEvent --> TriggerSkill[]
  self.legacy_skill_priority_table = {}
  self.legacy_refresh_skill_table = {}
  self.legacy_skills = {}    -- skillName[]

  self.game_event_stack = Stack:new()
  self.cleaner_stack = Stack:new()
  self.all_game_events = {}
  self.event_recorder = setmetatable({}, {
    -- 对派生事件而言 共用一个键 键取决于最接近GameEvent类的基类
    __newindex = function(t, k, v)
      if type(k) == "table" and k:isSubclassOf(GameEvent) then
        k = k:getBaseClass()
      end
      rawset(t, k, v)
    end,
    __index = function(t, k)
      if type(k) == "table" and k:isSubclassOf(GameEvent) then
        k = k:getBaseClass()
      end
      return rawget(t, k)
    end,
  })
  self.current_event_id = 0
  self.specific_events_id = {
    [GameEvent.Damage] = 1,
  }
  self.current_trigger_event_id = 0

  self.role_table = {
    { "lord" },
    { "lord", "rebel" },
    { "lord", "rebel", "renegade" },
    { "lord", "loyalist", "rebel", "renegade" },
    { "lord", "loyalist", "rebel", "rebel", "renegade" },
    { "lord", "loyalist", "rebel", "rebel", "rebel", "renegade" },
    { "lord", "loyalist", "loyalist", "rebel", "rebel", "rebel", "renegade" },
    { "lord", "loyalist", "loyalist", "rebel", "rebel", "rebel", "rebel", "renegade" },
  }
end

function GameLogic:run()
  -- default logic
  local room = self.room
  table.shuffle(self.room.players)
  self.room.game_started = true
  room:doBroadcastNotify("StartGame", "")
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

--- 安排座位。若有主公则作为1号位
function GameLogic:adjustSeats()
  local player_circle = {}
  local players = self.room.players
  local p = 1

  for i = 1, #players do
    if players[i].role == "lord" then
      p = i
      break
    end
  end
  for j = p, #players do
    table.insert(player_circle, players[j])
  end
  for j = 1, p - 1 do
    table.insert(player_circle, players[j])
  end

  self.room:arrangeSeats(player_circle)
end

--- 进行选将
function GameLogic:chooseGenerals()
  local room = self.room
  local generalNum = room.settings.generalNum
  local n = room.settings.enableDeputy and 2 or 1
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
  req.timeout = self.room.settings.generalTimeout
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

    local changer = Fk.game_modes[room.settings.gameMode]:getAdjustedProperty(p)
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
  local seed = math.random(2 << 32 - 1)
  room:prepareDrawPile(seed)
  room:doBroadcastNotify("PrepareDrawPile", seed)
  room:doBroadcastNotify("UpdateDrawPile", #room.draw_pile)
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
  for _, trig in ipairs(Fk.legacy_global_trigger) do
    self:addTriggerSkill(trig)
  end

  room:sendLog{ type = "$GameStart", arg = room.settings.gameMode }
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

--- 将一个触发技和它的关联触发技添加到房间（触发技必须添加到房间才能正常触发）
---@param skill TriggerSkill --|LegacyTriggerSkill
function GameLogic:addTriggerSkill(skill)
  if not skill then return end
  -- if skill:isInstanceOf(LegacyTriggerSkill) then
  --   ---@cast skill LegacyTriggerSkill
  --   self:addLegacyTriggerSkill(skill)
  --   return
  -- end

  ---@cast skill TriggerSkill
  if table.contains(self.skills, skill.name) then return end
  table.insert(self.skills, skill.name)
  local event = skill.event
  if self.skill_table[event] == nil then self.skill_table[event] = {} end
  table.insert(self.skill_table[event], skill)

  if self.skill_priority_table[event] == nil then
    self.skill_priority_table[event] = {}
  end

  local priority_tab = self.skill_priority_table[event]
  local prio = skill.priority
  if not table.contains(priority_tab, prio) then
    for i, v in ipairs(priority_tab) do
      if v < prio then
        table.insert(priority_tab, i, prio)
        break
      end
    end

    if not table.contains(priority_tab, prio) then
      table.insert(priority_tab, prio)
    end
  end

  if skill.visible then
    for _, s in ipairs(skill.related_skills) do
      if (s.class == TriggerSkill) then
        ---@cast s TriggerSkill
        self:addTriggerSkill(s)
      end
    end
  end
end

---@param event TriggerEvent|integer|string
---@param target? ServerPlayer
---@param data? any data应该传入一个构造好的某某class实例
function GameLogic:trigger(event, target, data, refresh_only)
  local broken = false --self:triggerForLegacy(event, target, data, refresh_only)
  if broken then return broken end
  if not (type(event) == "table" and event:isSubclassOf(TriggerEvent)) then
    return broken
  end

  local event_obj = event:new(self.room, target, data)
  event_obj.refresh_only = refresh_only
  return event_obj:exec()
end

-- 此为启动事件管理器并启动第一个事件的初始函数
function GameLogic:start()
  local root_event = GameEvent.Game:create()

  self:pushEvent(root_event)

  -- 此时的协程：room.main_co
  -- 事件管理器协程，同时也是Game事件
  -- 当新事件想要exec时，就切回此处，由这里负责调度协程
  -- 一个事件结束后也切回此处，然后resume
  local co = coroutine.create(function() return root_event:main() end)
  root_event._co = co

  while true do
    -- 对于cleaner和正常事件，处理更后面来的
    local ne = self:getCurrentEvent()
    local ce = self:getCurrentCleaner()
    local e = ce and (ce.id >= ne.id and ce or ne) or ne

    if not e then -- 没有事件，按理说不应该，平局处理
      self.room:sendLog{
        type = "#NoEventDraw",
        toast = true,
      }
      self.room:gameOver("")
    end

    if e == ne and e.killed then
      e.interrupted = true
      self:clearEvent(e)
      coroutine.close(e._co)
      e.status = "dead"
      e = self:getCurrentCleaner()
    end

    -- ret, evt解释：
    -- * true, nil: 中止
    -- * false, nil: 正常结束
    -- * true, GameEvent: 中止直到某event
    -- * false, GameEvent: 未结束，插入新event
    -- 若jump_to不为nil，表示正在中断至某某事件
    local ret, evt = self:resumeEvent(e)
    if evt == nil then
      e.interrupted = ret
      self:clearEvent(e)
      coroutine.close(e._co)
      e.status = "dead"
    elseif ret == true then
      -- 遍历栈，将shutdown图中的事件全标记上killed
      -- 被标记killed的事件之后会自动结束并清理
      for i = self.game_event_stack.p, 1, -1 do
        local event = self.game_event_stack.t[i]
        event.killed = true
        if event == evt then break end
      end
    end
  end
end

---@param event GameEvent
function GameLogic:pushEvent(event)
  self.game_event_stack:push(event)

  self.current_event_id = self.current_event_id + 1
  event.id = self.current_event_id
  self.all_game_events[event.id] = event
  self.event_recorder[event.event] = self.event_recorder[event.event] or {}
  table.insert(self.event_recorder[event.event], event)
end

-- 一般来说从GameEvent:exec切回start再被start调用
-- 作用是启动新事件 都是结构差不多的函数
---@param event GameEvent
---@return boolean, GameEvent?
function GameLogic:resumeEvent(event)
  local ret, evt

  local co = event._co
  local resume_reason = "unknown"

  while true do
    local err, yield_result, extra_yield_result = coroutine.resume(co, resume_reason)

    if err == false then
      -- handle error, then break
      if not string.find(yield_result, "__manuallyBreak") then
        fk.qCritical(yield_result .. "\n" .. debug.traceback(co) ..
          "\n" .. self:dumpEventStack())
      end
      ret = true
      break
    end

    if yield_result == "__handleRequest" then
      -- yield to requestLoop
      -- handleRequest类的最后被ResumeRoom唤醒，接收原因
      resume_reason = coroutine.yield(yield_result, extra_yield_result)

    elseif type(yield_result) == "table" and yield_result.class
      and yield_result:isInstanceOf(GameEvent) then

      if extra_yield_result == "__newEvent" then
        ret, evt = false, yield_result
        break
      elseif extra_yield_result == "__breakEvent" then
        ret, evt = true, yield_result
        if event.event ~= GameEvent.ClearEvent then break end
      end

    elseif yield_result == "__breakEvent" then
      ret = true
      if event.event ~= GameEvent.ClearEvent then break end

    else
      ret = false
      event.exec_ret = yield_result
      break
    end
  end

  return ret, evt
end

---@return GameEvent
function GameLogic:getCurrentCleaner()
  return self.cleaner_stack.t[self.cleaner_stack.p]
end

-- 事件中的清理。
-- cleaner单独开协程运行，exitFunc须转到上个事件的协程内执行
-- 注意插入新event
---@param event GameEvent
function GameLogic:clearEvent(event)
  if event.event == GameEvent.ClearEvent then return end
  if event.status == "exiting" then return end
  event.status = "exiting"
  local ce = GameEvent.ClearEvent:create(event)
  ce.id = self.current_event_id
  local co = coroutine.create(function() return ce:main() end)
  ce._co = co
  self.cleaner_stack:push(ce)
end

---@return GameEvent
function GameLogic:getCurrentEvent()
  return self.game_event_stack.t[self.game_event_stack.p]
end

function GameLogic:getCurrentEventDepth()
  return self.game_event_stack.p
end

---@param eventType GameEvent
function GameLogic:getMostRecentEvent(eventType)
  return self:getCurrentEvent():findParent(eventType, true)
end

--- 如果当前事件刚好是技能生效事件，就返回那个技能名，否则返回空串。
---@return string|nil
function GameLogic:getCurrentSkillName()
  local skillEvent = self:getCurrentEvent()
  local ret = nil
  if skillEvent.event == GameEvent.SkillEffect then
    local _skill = skillEvent.data.skill
    local skill = _skill.main_skill and _skill.main_skill or _skill
    ret = skill.name
  end
  return ret
end

-- 在指定历史范围中找至多n个符合条件的事件
---@generic T: GameEvent
---@param eventType T @ 要查找的事件类型
---@param n integer @ 最多找多少个
---@param func fun(e: T): boolean? @ 过滤用的函数
---@param scope integer @ 查询历史范围，只能是当前阶段/回合/轮次
---@return T[] @ 找到的符合条件的所有事件，最多n个但不保证有n个
function GameLogic:getEventsOfScope(eventType, n, func, scope)
  scope = scope or Player.HistoryTurn
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
  return start_event:searchEvents(eventType, n, func)
end

-- 在指定历史范围中找符合条件的事件（逆序）
---@generic T: GameEvent
---@param eventType T @ 要查找的事件类型
---@param func fun(e: T): boolean? @ 过滤用的函数
---@param n integer @ 最多找多少个
---@param end_id? integer @ 查询历史范围：从最后的事件开始逆序查找直到id为end_id的事件（不含），默认当前事件的id
---@param scope? integer @ 查询历史范围：当有此参数时end_id参数失效，改为查找当前阶段/回合/轮次/游戏
---@return T[] @ 找到的符合条件的所有事件，最多n个但不保证有n个
function GameLogic:getEventsByRule(eventType, n, func, end_id, scope)
  if scope then
    local end_event ---@type GameEvent?
    if scope == Player.HistoryGame then
      end_id = 0
    elseif scope == Player.HistoryRound then
      end_event = self:getCurrentEvent():findParent(GameEvent.Round, true)
    elseif scope == Player.HistoryTurn then
      end_event = self:getCurrentEvent():findParent(GameEvent.Turn, true)
    elseif scope == Player.HistoryPhase then
      end_event = self:getCurrentEvent():findParent(GameEvent.Phase, true)
    end
    if end_event then
      end_id = end_event.id
    end
  end
  if end_id == nil then
    end_id = self:getCurrentEvent().id
  end
  local ret = {}
	local events = self.event_recorder[eventType] or Util.DummyTable
  for i = #events, 1, -1 do
    local e = events[i]
    if e.id <= end_id then break end
    if func(e) then
      table.insert(ret, e)
      if #ret >= n then break end
    end
  end
  return ret
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

function GameLogic:dumpEventStack()
  local top = self:getCurrentEvent()
  local i = self.game_event_stack.p
  if not top then return end

  local ret = "===== Start of event stack dump =====\n"

  repeat
    ret = ret .. tostring(top) .. "\n"

    top = top.parent
    i = i - 1
  until not top

  ret = ret .. "===== End of event stack dump =====\n"
  return ret
end

function GameLogic:dumpAllEvents(from, to)
  from = from or 1
  to = to or #self.all_game_events
  assert(from <= to)

  local indent = 0
  local tab = "  "
  for i = from, to, 1 do
    local v = self.all_game_events[i]
    if type(v) ~= "table" or not v:isInstanceOf(GameEvent) then
      indent = math.max(indent - 1, 0)
      -- v = "End"
      -- print(tab:rep(indent) .. string.format("#%d: %s", i, v))
    else
      print(tab:rep(indent) .. tostring(v))
      if v.id ~= v.end_id then
        indent = indent + 1
      end
    end
  end
end

function GameLogic:breakEvent(ret)
  coroutine.yield("__breakEvent", ret)
end

function GameLogic:breakTurn()
  local event = self:getCurrentEvent():findParent(GameEvent.Turn)
  if not event then return end
  event:shutdown()
end

return GameLogic
