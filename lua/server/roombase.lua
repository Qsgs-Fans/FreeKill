--- 各种Room的第二基类 提供最基本的与Cpp交互 和scheduler协作运行的设施与方法
---@class ServerRoomBase : Base.RoomBase
---@field public id integer @ 房间的id
---@field public room fk.Room @ C++层面的Room类实例，别管他就是了，用不着
---@field public hidden_players fk.ServerPlayer[] @ 未上场的玩家们（不是角色）
---@field public unused_bots fk.ServerPlayer[] @ 未上场的人机们
---@field public main_co any @ 本房间的主协程
---@field public tag table<string, any> @ tag类似banner，但是只存在于服务端，可用于强行制造信息不对等
---@field public game_started boolean @ 游戏是否已经开始
---@field public game_finished boolean @ 游戏是否已经结束
---@field public serverplayer_klass any
---@field public logic_klass any
---@field public logic Base.GameLogic @ 这个房间使用的游戏逻辑，可能根据游戏模式而变动
---@field public current_request Request @ 当前正在处理中的request
---@field public last_request Request @ 上一次完成的request
---@field public _test_disable_delay boolean? 测试专用 会禁用delay和烧条
---@field public callbacks { [string|integer]: fun(self, sender: integer, data) }
---@field private _resume_fn fun(reason): boolean? 判断对于reason是否接受唤醒
local ServerRoomBase = {}

---@param _room fk.Room
function ServerRoomBase:initialize(_room)
  self.room = _room
  self.id = _room:getId()

  self.hidden_players = {}
  self.unused_bots = {}

  self.tag = {}

  self.game_started = false
  self.game_finished = false

  -- doNotify过载保护，每次获得控制权时置为0
  -- 若在yield之前执行了max次doNotify则强制让出
  self.notify_count = 0
  self.notify_max = 500

  self.timeout = _room:getTimeout()
  self.settings = cbor.decode(self.room:settings())

  self._rand_seed = math.random(os.time())
  self._rng = fk.rand(self._rand_seed)
  self._resume_fn = Util.TrueFunc

  self.callbacks = {}
  ------------------------
  self:addCallback("reconnect", self.playerReconnect)
  self:addCallback("observe", self.addObserver)
  self:addCallback("leave", self.removeObserver)
  self:addCallback("surrender", self.handleSurrender)
end

---@param check_fn? fun(reason: string): boolean?
function ServerRoomBase:yield(check_fn, ...)
  check_fn = check_fn or Util.TrueFunc
  self._resume_fn = check_fn
  return coroutine.yield("__handleRequest", ...)
end

---@param func fun(self, sender: integer, data)
function ServerRoomBase:addCallback(command, func)
  self.callbacks[command] = func
end

-- 供调度器使用的函数。能让房间开始运行/从挂起状态恢复。
---@param reason string?
function ServerRoomBase:resume(reason)
  -- 如果还没运行的话就先创建自己的主协程
  if not self.main_co then
    self.main_co = coroutine.create(function()
      self:run()
    end)
  end

  local ret, err_msg, rest_time = true, true, nil
  local main_co = self.main_co

  -- 高优先事项：无人时不继续游戏了，直接结束
  if self:checkNoHuman() then
    goto GAME_OVER
  end

  -- 若有reason且拒绝被reason唤醒，则不管他了
  if reason and not self._resume_fn(reason) then
    return false
  end
  -- 立刻设置回去防止某处漏了导致锁死
  self._resume_fn = Util.TrueFunc

  if not self.game_finished then
    self.notify_count = 0

    ret, err_msg, rest_time = coroutine.resume(main_co, reason)

    -- handle error
    if ret == false then
      fk.qCritical(err_msg .. "\n" .. debug.traceback(main_co))
      goto GAME_OVER
    end

    if rest_time == "over" then
      goto GAME_OVER
    end

    return false, rest_time
  end

  ::GAME_OVER::
  if not self.game_finished then
    self:gameOver("")
    -- coroutine.close(main_co)
    -- self.main_co = nil
  end
  return true
end

function ServerRoomBase:checkNoHuman(chkOnly)
  if #self.players == 0 then return end
  for _, p in ipairs(self.players) do
    local state = p.serverplayer:getState()
    if state == fk.Player_Online or state == fk.Player_Trust then
      return
    end
  end

  if not chkOnly then
    self:gameOver("")
  end
  return true
end


--- 正式在这个房间中开始游戏。
---
--- 当这个函数返回之后，整个Room线程也宣告结束。
---@return nil
function ServerRoomBase:run()
  self.start_time = os.time()
  for _, p in fk.qlist(self.room:getPlayers()) do
    local player = self.serverplayer_klass:new(p)
    player.room = self
    table.insert(self.players, player)
  end

  -- 尽可能早的将提前上树的人带到游戏界面
  local all_observers = self.room:getObservers()
  for _, p in fk.qlist(all_observers) do
    self:tellRoomToObserver(p)
    -- 由于代码机制，旁观者先被踢出房间了，这里只和旁观者同步
    for _, p2 in fk.qlist(all_observers) do
      p2:doNotify("AddObserver", cbor.encode {
        p:getId(),
        p:getScreenName(),
        p:getAvatar(),
        false,
        p:getTotalGameTime(),
      })
    end
  end

  local mode = Fk.game_modes[self:getSettings('gameMode')]
  local logic = (mode.logic and mode.logic() or self.logic_klass):new(self)
  self.logic = logic
  if mode.rule then self:addSkill(mode.rule) end
  logic:start()
end

--- 按输入的角色表重新改变座位。若无输入，仅更新角色座位UI
function ServerRoomBase:arrangeSeats(players)
  assert(players == nil or #players == #self.players)
  players = players or self.players
  self.players = players

  for i = 1, #players do
    players[i].seat = i
    players[i].next = players[i + 1] or players[1]
  end

  local player_circle = table.map(players, Util.IdMapper)
  self:doBroadcastNotify("ArrangeSeats", player_circle)
end


--- 向多名玩家广播一条消息。
---@param command string @ 发出这条消息的消息类型
---@param jsonData any @ 消息的数据，一般是JSON字符串，也可以是普通字符串，取决于client怎么处理了
---@param players? ServerPlayerBase[] @ 要告知的玩家列表，默认为所有人
function ServerRoomBase:doBroadcastNotify(command, jsonData, players)
  players = players or self.players
  for _, p in ipairs(players) do
    p:doNotify(command, jsonData)
  end
end

--- 向所有角色广播一名角色的某个property，让大家都知道
---@param player Base.Player @ 要被广而告之的那名角色
---@param property string @ 这名角色的某种属性，像是"hp"之类的，其实就是Player类的属性名
function ServerRoomBase:broadcastProperty(player, property)
  for _, p in ipairs(self.players) do
    self:notifyProperty(p, player, property)
  end
end

--- 设置角色的某个属性，并广播给所有人
---@param player Base.Player
---@param property string @ 属性名称
function ServerRoomBase:setPlayerProperty(player, property, value)
  player[property] = value
  self:broadcastProperty(player, property)
end

--- 将player的属性property告诉p。
---@param p ServerPlayerBase @ 要被告知相应属性的那名玩家
---@param player Base.Player @ 拥有那个属性的玩家
---@param property string @ 属性名称
function ServerRoomBase:notifyProperty(p, player, property)
  p:doNotify("PropertyUpdate", {
    player.id,
    property,
    player[property],
  })
end

--- 将焦点转移给一名或者多名角色，并广而告之。
---
--- 形象点说，就是在那些玩家下面显示一个“弃牌 思考中...”之类的烧条提示。
---@param players Base.Player | Base.Player[] @ 要获得焦点的一名或者多名角色
---@param command string @ 烧条的提示文字
---@param timeout integer? @ focus的烧条时长
function ServerRoomBase:notifyMoveFocus(players, command, timeout)
  if (players.class) then
    players = {players}
  end

  local ids = {}
  for _, p in ipairs(players) do
    table.insert(ids, p.id)
  end

  self:doBroadcastNotify("MoveFocus", {
    ids,
    command,
    timeout
  })
end


--- 向战报中发送一条log。
---@param log LogMessage @ Log的实际内容
function ServerRoomBase:sendLog(log)
  self:doBroadcastNotify("GameLog", log)
end

--- 播放某种动画效果给players看。
---@param type string @ 动画名字
---@param data any @ 这个动画附加的额外信息，在这个函数将会被转成json字符串
---@param players? ServerPlayerBase[] @ 要观看动画的玩家们，默认为全员
function ServerRoomBase:doAnimate(type, data, players)
  players = players or self.players
  data.type = type
  self:doBroadcastNotify("Animate", data, players)
end

--- 延迟一段时间。
---@param ms integer @ 要延迟的毫秒数
function ServerRoomBase:delay(ms)
  self.room:delay(math.ceil(ms))
  if self._test_disable_delay then return end
  self:yield(function(r) return r == "delay_done" end, ms)
end

--- 将触发技或状态技添加到房间
---@param skill Skill|string
function ServerRoomBase:addSkill(skill)
  if type(skill) == "string" then
    skill = Fk.skills[skill]
  end
  if skill == nil then return end
  if skill:isInstanceOf(StatusSkill) then
    self.status_skills[skill.class] = self.status_skills[skill.class] or {}
    table.insertIfNeed(self.status_skills[skill.class], skill)
    -- add status_skill to cilent room
    self:doBroadcastNotify("AddStatusSkill", { skill.name })
  elseif skill:isInstanceOf(TriggerSkill) then
    ---@cast skill TriggerSkill
    self.logic:addTriggerSkill(skill)
  end
  for _, s in ipairs(skill.related_skills) do
    self:addSkill(s)
  end
end

--- 检查房间是否已经被加入了触发技或状态技
---@param skill Skill|string
---@return boolean
function ServerRoomBase:hasSkill(skill)
  if type(skill) == "string" then
    skill = Fk.skills[skill]
  end
  if skill == nil then return false end
  if skill:isInstanceOf(StatusSkill) then
    if type(self.status_skills[skill.class]) == "table" then
      return table.contains(self.status_skills[skill.class], skill)
    end
  elseif skill:isInstanceOf(TriggerSkill) then
    ---@cast skill TriggerSkill
    local event = skill.event
    if type(self.logic.skill_table[event]) == "table" then
      return table.contains(self.logic.skill_table[event], skill)
    end
  end
  return false
end

--- 将某个技能作为预亮技能添加给一名角色，并（将触发技）加入房间
---@param player ServerPlayer
---@param skill string
function ServerRoomBase:addFakeSkill(player, skill)
  player:addFakeSkill(skill)
  local toget = {table.unpack(Fk.skill_skels[skill].effects)}
  for _, s in ipairs(toget) do
    if s:isInstanceOf(TriggerSkill) then
      ---@cast s TriggerSkill
      self.logic:addTriggerSkill(s)
    end
    --self:addSkill
  end
end

function ServerRoomBase:shouldUpdateWinRate()
  if self:getSettings("enableFreeAssign") then
    return false
  end
  if os.time() - self.start_time < 45 then
    return false
  end

  -- 由于召唤术的存在，人机不能一刀切的不算分
  -- 话说为什么这玩意在ServerRoomBase，还有顶上的自选武将，这乱套了啊
  for _, p in ipairs(self.players) do
    if p.id < 0 and (p._controller_stack or {})[1] == p._splayer then return false end
  end
  return Fk.game_modes[self:getSettings('gameMode')]:countInFunc(self)
end

--- 获取一名角色一局游戏的胜负结果。
--- 胜利1；失败2；平局3。
---@param winner string @ 获胜的玩家id字符串，空字符串表示平局
---@param pid string | number @ 角色的id
---@return integer @ 胜负结果
function ServerRoomBase:victoryResult(winner, pid)
  local ret
  if winner == "" then
    ret = 3
  elseif table.contains(winner:split("+"), tostring(pid)) then
    ret = 1
  else
    ret = 2
  end
  return ret
end

---@param winners string @ 获胜玩家的id字符串
function ServerRoomBase:gameOver(winners)
  if not self.game_started then return end
  self.room:destroyRequestTimer()

  local winPlayers = table.map(winners:split("+"), function(id) return self:getPlayerById(tonumber(id)) end)
  if table.contains(
    { "running", "normal" },
    coroutine.status(self.main_co)
  ) then
    self.logic:trigger(fk.GameFinished, nil, { players = winPlayers })
  end

  self.game_started = false
  self.game_finished = true

  -- 兜底一个player胜率？
  if self:shouldUpdateWinRate() then
    for _, p in ipairs(self.players) do
      local id = p.id
      local mode = self:getSettings('gameMode')
      local result

      if p.id > 0 then
        result = self:victoryResult(winners, tostring(p.id))
        self.room:updatePlayerWinRate(id, mode, p.role or "", result)
      end
    end
  end

  local winRoles = {}
  for _, p in ipairs(winPlayers) do
    table.insertIfNeed(winRoles, p.role)
  end
  self:doBroadcastNotify("GameOver", winners)
  fk.qInfo(string.format("[GameOver] %d, %s, %s, in %ds", self.id, self:getSettings('gameMode'),
  table.concat(winRoles, "+"),
  os.time() - self.start_time))

  self.room:gameOver()

  if table.contains(
    { "running", "normal" },
    coroutine.status(self.main_co)
  ) then
    coroutine.yield("__handleRequest", "over")
  else
    coroutine.close(self.main_co)
    self.main_co = nil
  end
end

function ServerRoomBase:playerReconnect(id)
  local p = self:getPlayerById(id)
  if p then
    p:reconnect()
  end
end

function ServerRoomBase:tellRoomToObserver(player)
  local observee = self.players[1]
  local start_time = os.getms()
  local summary = self:serialize(observee)
  summary.settings = table.clone(summary.settings)
  summary.settings.isObserver = true
  player:doNotify("Observe", cbor.encode(summary))
  -- 由于开战前旁观的加入，旁观者能回到等待界面了，有必要知道谁是主
  player:doNotify("RoomOwner", cbor.encode { self.room:getOwner():getId() })

  fk.qInfo(string.format("[Observe] %d, %s, in %.3fms",
    self.id, player:getScreenName(), (os.getms() - start_time) / 1000))

  table.insert(self.observers, {observee.id, player, player:getId()})
end

function ServerRoomBase:addObserver(id)
  local all_observers = self.room:getObservers()
  for _, p in fk.qlist(all_observers) do
    if p:getId() == id then
      self:tellRoomToObserver(p)
      -- TODO: (v0.6) 记得删除这个，0.6的时候旁观者添加和移除统一到cpp
      self:doBroadcastNotify("AddObserver", {
        p:getId(),
        p:getScreenName(),
        p:getAvatar(),
        false,
        p:getTotalGameTime(),
      })
      break
    end
  end
end

function ServerRoomBase:removeObserver(id)
  for i, t in ipairs(self.observers) do
    local pid = t[3]
    if pid == id then
      table.remove(self.observers, i)
      -- TODO: (v0.6) 记得删除这个，0.6的时候旁观者添加和移除统一到cpp
      self:doBroadcastNotify("RemoveObserver", { pid })
      break
    end
  end
end

function ServerRoomBase:handleSurrender(id, data)
-- request_handlers["surrender"] = function(room, id, reqlist)
  local player = self:getPlayerById(id)
  if not player then return end

  player.surrendered = true
  if Fk.game_modes[self:getSettings('gameMode')]:getWinner(player) == "" then
    player.surrendered = false
    return
  end

  self.hasSurrendered = true
  self:doBroadcastNotify("CancelRequest", "")
  ResumeRoom(self.id)
end

--- 将房间中某个tag设为特定值。
--- 
--- 注意：客户端无法获取room tag，请改用```setBanner```
--- 
--- 当想在服务端搞点全局变量时，不要自己设置全局变量或者上值，而应该使用room的tag。
---@param tag_name string @ tag名字
---@param value any @ 值
function ServerRoomBase:setTag(tag_name, value)
  self.tag[tag_name] = value
end

--- 获得某个tag的值。
---@param tag_name string @ tag名字
function ServerRoomBase:getTag(tag_name)
  return self.tag[tag_name]
end

--- 删除某个tag。
---@param tag_name string @ tag名字
function ServerRoomBase:removeTag(tag_name)
  self.tag[tag_name] = nil
end

--- 将一名玩家的某种标记设置为某值，并通知所有客户端更新。
--- 
--- 值可以是数字、字符串、表、键值表等。注意键值表做值时键值表的键不能是数字。
--- 
--- 通用的mark名称及后缀参见`mark_enum.lua`。
--- 
-- mark name and UI:
--
-- ```xxx```: invisible mark
--
-- ```@xxx```: mark with extra data (maybe string or number) 表会显示所有元素，以空格分隔
--
-- ```@@xxx```: mark with invisible extra data
--
-- ```@$xxx```: mark with card_name[] or card_integer[] data
--
-- ```@&xxx```: mark with general_name[] data
--
-- ```@!xxx```: picMark shown on the bottom-right corner of the photo, @!! for notation
---@param player Base.Player @ 更新标记的玩家
---@param mark string @ 标记的名称
---@param value any @ 设置的值，可以是数字、字符串、表、键值表等
function ServerRoomBase:setPlayerMark(player, mark, value)
  player:setMark(mark, value)
  self:doBroadcastNotify("SetPlayerMark", {
    player.id,
    mark,
    value
  })
end

--- 将一名玩家的```mark```标记增加```count```个，并通知所有客户端更新。
--- 
--- tableMark有封装方法```addTableMark```和```addTableMarkIfNeed```
---@param player Base.Player @ 加标记的玩家
---@param mark string @ 标记名称
---@param count? integer @ 增加的数量，默认为1
function ServerRoomBase:addPlayerMark(player, mark, count)
  count = count or 1
  local num = player:getMark(mark)
  num = num or 0
  self:setPlayerMark(player, mark, math.max(num + count, 0))
end

--- 将一名玩家的```mark```标记减少```count```个，并通知所有客户端更新。
--- 
--- tableMark有封装方法```removeTableMark```
---@param player Base.Player @ 减标记的玩家
---@param mark string @ 标记名称
---@param count? integer  @ 减少的数量，默认为1
function ServerRoomBase:removePlayerMark(player, mark, count)
  count = count or 1
  local num = player:getMark(mark)
  num = num or 0
  self:setPlayerMark(player, mark, math.max(num - count, 0))
end

--- 设置房间banner，显示于左上角，用于模式介绍、仁区等
--- 
--- 房间版mark
---@param name string @ banner的名称
---@param value any
function ServerRoomBase:setBanner(name, value)
  Fk.Base.RoomBase.setBanner(self, name, value)
  self:doBroadcastNotify("SetBanner", { name, value })
end

-- 生成随机数。该随机数只与当前游戏房间有关，
-- 以便后续可以只根据随机数种子和玩家的决策来重现整个对局。
function ServerRoomBase:random(m, n)
  return self._rng:random(m, n)
end

-- 重置房间的随机数种子，仅用于复盘阶段
function ServerRoomBase:randomseed(x, y)
  return self._rng:randomseed(x, y)
end

--- 基于本房间的随机发生器来原地打乱某个表。
---@generic T
---@param t T[]
function ServerRoomBase:shuffleTable(t)
  if #t == 2 then
    if self:random() < 0.5 then
      t[1], t[2] = t[2], t[1]
    end
  else
    for i = #t, 2, -1 do
      local j = self:random(i)
      t[i], t[j] = t[j], t[i]
    end
  end
end

---@generic T
---@param t T[]
---@return T
---@diagnostic disable-next-line
function ServerRoomBase:tableRandomPick(t) end

--- 基于本房间的随机发生器来从表中随机选取
---@generic T
---@param t T[]
---@param n integer
---@return T[]
---@diagnostic disable-next-line: duplicate-set-field
function ServerRoomBase:tableRandomPick(t, n)
  local n0 = n
  n = n or 1
  if #t == 0 then return n0 ~= nil and {} or nil end
  local tmp = {table.unpack(t)}
  local ret = {}
  while n > 0 and #tmp > 0 do
    local i = self:random(1, #tmp)
    table.insert(ret, table.remove(tmp, i))
    n = n - 1
  end
  return n0 == nil and ret[1] or ret
end

function ServerRoomBase:serialize(player)
  local klass = self.class.super --[[@as Base.RoomBase]]
  local o = klass.serialize(self)
  if player then
    o.you = player.id
  end
  return o
end

function ServerRoomBase:getSessionId()
  if type(self.room.getSessionId) ~= "function" then
    fk.qWarning("Room::getSessionId doesn't exist, please use freekill-asio 0.0.8+")
    return 0
  end

  return self.room:getSessionId()
end

function ServerRoomBase:getSessionData()
  if type(self.room.getSessionData) ~= "function" then
    fk.qWarning("Room::getSessionData doesn't exist, please use freekill-asio 0.0.8+")
    return {}
  end

  local data = self.room:getSessionData()
  local ok, result = pcall(json.decode, data or "{}")
  if ok then
    return result
  else
    fk.qWarning("Failed to decode save data: " .. data)
    return {}
  end
end

function ServerRoomBase:setSessionData(data)
  if type(self.room.setSessionData) ~= "function" then
    fk.qWarning("Room::setSessionData doesn't exist, please use freekill-asio 0.0.8+")
    return 0
  end

  local ok, jsonData = pcall(json.encode, data)
  if ok then
    self.room:setSessionData(jsonData)
  else
    fk.qWarning("Failed to encode global save data: " .. data)
  end
end

-- 向本房间players列表添加一个新玩家，并通知客户端
---@param nextPlayer ServerPlayerBase 新玩家的下家
function ServerRoomBase:addNpc(nextPlayer)
  local bot_splayer = table.remove(self.unused_bots) ---@type fk.ServerPlayer
  if not bot_splayer then
    bot_splayer = self.room:addNpc()
  end

  local bot = self.serverplayer_klass:new(bot_splayer)
  bot.room = self

  table.insert(self.players, table.indexOf(self.players, nextPlayer), bot)
  self:doBroadcastNotify("AddNpc", {
    bot_splayer:getId(),
    bot_splayer:getScreenName(),
    bot_splayer:getAvatar(),
    true,
    0,
  })
  self:arrangeSeats()

  return bot
end

--- 全局存档
---@param key string 存档名
---@param data table
function ServerRoomBase:saveGlobalState(key, data)
  if not self.room then return nil end
  if type(self.room.saveGlobalState) ~= "function" then
    fk.qWarning("self._splayer.saveGlobalState doesn't exist, Please ensure that the server version is freekill-asio 0.0.6+")
    return nil
  end
  local ok, jsonData = pcall(json.encode, data)
  if ok then
    local ret = self.room:saveGlobalState(key, jsonData)
    if type(ret) == "boolean" then
      self:yield(function(r) return r == "query_done" end)
    end
  else
    fk.qWarning("Failed to encode global save data: " .. jsonData)
  end
end

--- 获取全局存档
---@param key string 存档名
---@return table @ 不存在返回空表
function ServerRoomBase:getGlobalSaveState(key)
  if not self.room then return {} end
  if type(self.room.getGlobalSaveState) ~= "function" then
    fk.qWarning("self._splayer.getGlobalSaveState doesn't exist, Please ensure that the server version is freekill-asio 0.0.6+")
    return {}
  end
  local data = self.room:getGlobalSaveState(key)
  if type(data) == "boolean" then
    data = self:yield(function(reason)
      local ok = pcall(json.decode, reason)
      return ok
    end)
  end
  local ok, result = pcall(json.decode, data or "{}")
  if ok then
    return result
  else
    fk.qWarning("Failed to decode global save data: " .. result)
    return {}
  end
end


return ServerRoomBase
