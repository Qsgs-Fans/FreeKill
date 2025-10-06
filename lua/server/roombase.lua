--- 各种Room的第二基类 提供最基本的与Cpp交互 和scheduler协作运行的设施与方法
---@class ServerRoomBase : Base.RoomBase
---@field public id integer @ 房间的id
---@field public room fk.Room @ C++层面的Room类实例，别管他就是了，用不着
---@field public main_co any @ 本房间的主协程
---@field public tag table<string, any> @ tag类似banner，但是只存在于服务端，可用于强行制造信息不对等
---@field public game_started boolean @ 游戏是否已经开始
---@field public game_finished boolean @ 游戏是否已经结束
---@field public serverplayer_klass any
---@field public logic_klass any
---@field public logic Base.GameLogic @ 这个房间使用的游戏逻辑，可能根据游戏模式而变动
---@field public last_request Request @ 上一次完成的request
---@field public _test_disable_delay boolean? 测试专用 会禁用delay和烧条
---@field public callbacks { [string|integer]: fun(self, sender: integer, data) }
local ServerRoomBase = {}

---@param _room fk.Room
function ServerRoomBase:initialize(_room)
  self.room = _room
  self.id = _room:getId()

  self.tag = {}

  self.game_started = false
  self.game_finished = false

  -- doNotify过载保护，每次获得控制权时置为0
  -- 若在yield之前执行了max次doNotify则强制让出
  self.notify_count = 0
  self.notify_max = 500

  self.timeout = _room:getTimeout()
  self.settings = cbor.decode(self.room:settings())

  self.callbacks = {}
  ------------------------
  self:addCallback("reconnect", self.playerReconnect)
  self:addCallback("observe", self.addObserver)
  self:addCallback("leave", self.removeObserver)
  self:addCallback("surrender", self.handleSurrender)
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

  if self:checkNoHuman() then
    goto GAME_OVER
  end

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

  local mode = Fk.game_modes[self.settings.gameMode]
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
  coroutine.yield("__handleRequest", ms)
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

function ServerRoomBase:shouldUpdateWinRate()
  if self.settings.enableFreeAssign then
    return false
  end
  if os.time() - self.start_time < 45 then
    return false
  end
  for _, p in ipairs(self.players) do
    if p.id < 0 then return false end
  end
  return Fk.game_modes[self.settings.gameMode]:countInFunc(self)
end

--- 获取一名角色一局游戏的胜负结果。
--- 胜利1；失败2；平局3。
---@param winner string @ 获胜的身份，空字符串表示平局
---@param role string @ 角色的身份
---@return integer @ 胜负结果
function ServerRoomBase:victoryResult(winner, role)
  local ret
  if winner == "" then
    ret = 3
  elseif table.contains(winner:split("+"), role) then
    ret = 1
  else
    ret = 2
  end
  return ret
end

function ServerRoomBase:gameOver(winner)
  if not self.game_started then return end
  self.room:destroyRequestTimer()

  if table.contains(
    { "running", "normal" },
    coroutine.status(self.main_co)
  ) then
    self.logic:trigger(fk.GameFinished, nil, winner)
  end

  self:doBroadcastNotify("GameOver", winner)
  fk.qInfo(string.format("[GameOver] %d, %s, %s, in %ds", self.id, self.settings.gameMode, winner, os.time() - self.start_time))

  self.game_started = false
  self.game_finished = true

  -- 兜底一个player胜率？
  if self:shouldUpdateWinRate() then
    for _, p in ipairs(self.players) do
      local id = p.id
      local mode = self.settings.gameMode
      local result

      if p.id > 0 then
        result = self:victoryResult(winner, p.role)
        self.room:updatePlayerWinRate(id, mode, p.role, result)
      end
    end
  end

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
  player:doNotify("Observe", cbor.encode(summary))

  fk.qInfo(string.format("[Observe] %d, %s, in %.3fms",
    self.id, player:getScreenName(), (os.getms() - start_time) / 1000))

  table.insert(self.observers, {observee.id, player, player:getId()})
end

function ServerRoomBase:addObserver(id)
  local all_observers = self.room:getObservers()
  for _, p in fk.qlist(all_observers) do
    if p:getId() == id then
      self:tellRoomToObserver(p)
      self:doBroadcastNotify("AddObserver", {
        p:getId(),
        p:getScreenName(),
        p:getAvatar()
      })
      break
    end
  end
end

function ServerRoomBase:removeObserver(id)
  for _, t in ipairs(self.observers) do
    local pid = t[3]
    if pid == id then
      table.removeOne(self.observers, t)
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
  if Fk.game_modes[self.settings.gameMode]:getWinner(player) == "" then
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

function ServerRoomBase:serialize(player)
  local klass = self.class.super --[[@as Base.RoomBase]]
  local o = klass.serialize(self)
  if player then
    o.you = player.id
  end
  return o
end

return ServerRoomBase
