-- SPDX-License-Identifier: GPL-3.0-or-later

--- Room是fk游戏逻辑运行的主要场所，同时也提供了许多API函数供编写技能使用。
---
--- 一个房间中只有一个Room实例，保存在RoomInstance全局变量中。
---@class Room : AbstractRoom, GameEventWrappers, CompatAskFor
---@field public room fk.Room @ C++层面的Room类实例，别管他就是了，用不着
---@field public id integer @ 房间的id
---@field private main_co any @ 本房间的主协程
---@field public players ServerPlayer[] @ 这个房间中所有参战玩家
---@field public alive_players ServerPlayer[] @ 所有还活着的玩家
---@field public observers fk.ServerPlayer[] @ 旁观者清单，这是c++玩家列表，别乱动
---@field public current ServerPlayer @ 当前回合玩家
---@field public game_started boolean @ 游戏是否已经开始
---@field public game_finished boolean @ 游戏是否已经结束
---@field public tag table<string, any> @ Tag清单，其实跟Player的标记是差不多的东西
---@field public general_pile string[] @ 武将牌堆，这是可用武将名的数组
---@field public logic GameLogic @ 这个房间使用的游戏逻辑，可能根据游戏模式而变动
---@field public request_queue table<userdata, table>
---@field public request_self table<integer, integer>
---@field public last_request Request @ 上一次完成的request
---@field public skill_costs table<string, any> @ 存放skill.cost_data用
---@field public card_marks table<integer, any> @ 存放card.mark之用
---@field public current_cost_skill TriggerSkill? @ AI用
---@field public _test_disable_delay boolean? 测试专用 会禁用delay和烧条
local Room = AbstractRoom:subclass("Room")

-- load classes used by the game
Request = require "server.network"
GameEvent = require "server.gameevent"
GameEventWrappers = require "lua.server.events"
Room:include(GameEventWrappers)
GameLogic = require "server.gamelogic"
ServerPlayer = require "server.serverplayer"

CompatAskFor = require "compat.askfor"
Room:include(CompatAskFor)

-- 唉，兼容牢函数
GameLogic:include(dofile "lua/compat/gamelogic.lua")

---@type Player
Self = nil -- `Self' is client-only, but we need it in AI
dofile "lua/server/ai/init.lua"

--[[--------------------------------------------------------------------
  Room 保存着服务器端游戏房间的所有信息，比如说玩家、卡牌，以及其他信息。
  同时它也提供大量方法，以便于游戏能够顺利运转。

  class Room 的大概内容：
  * 构造方法
  * getter/setters
  * 基本的网络通信相关方法、通知用方法
  * 交互式方法
  * 各种触发游戏事件的方法

  另请参考：
    gamelogic.lua (游戏逻辑的主循环、触发时机等)
    gameevent.lua (游戏事件的执行逻辑，以及各种事件的执行方法)
    game_rule.lua (基础游戏规则，包括执行阶段、决胜负等)
    aux_skills.lua (某些交互方法是套壳askForUseActiveSkill，就是在这定义的)
    aux_poxi.lua (有了Poxi之后，一些交互方法改成了以各种PoxiMethod为基础的交互)
]]----------------------------------------------------------------------

------------------------------------------------------------------------
-- 构造函数
------------------------------------------------------------------------

--- 构造函数。别去构造
---@param _room fk.Room
function Room:initialize(_room)
  AbstractRoom.initialize(self)
  self.room = _room
  self.id = _room:getId()

  self.game_started = false
  self.game_finished = false
  self.timeout = _room:getTimeout()
  self.tag = {}
  self.general_pile = {}
  self.request_queue = {}
  self.request_self = {}

  -- doNotify过载保护，每次获得控制权时置为0
  -- 若在yield之前执行了max次doNotify则强制让出
  self.notify_count = 0
  self.notify_max = 500

  self.settings = json.decode(self.room:settings())
  self.disabled_packs = self.settings.disabledPack
  if not Fk.game_modes[self.settings.gameMode] then
    self.settings.gameMode = "aaa_role_mode"
  end

  table.insertTable(self.disabled_packs, Fk.game_mode_disabled[self.settings.gameMode])
  self.disabled_generals = self.settings.disabledGenerals
end

-- 供调度器使用的函数。能让房间开始运行/从挂起状态恢复。
---@param reason string?
function Room:resume(reason)
  -- 如果还没运行的话就先创建自己的主协程
  if not self.main_co then
    self.main_co = coroutine.create(function()
      self:makeGeneralPile()
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
  self:gameOver("")
  -- coroutine.close(main_co)
  -- self.main_co = nil
  return true
end

-- 构造武将牌堆
function Room:makeGeneralPile()
  local trueNames = {}
  local ret = {}
  if self.game_started then
    for _, player in ipairs(self.players) do
      trueNames[Fk.generals[player.general].trueName] = true
    end
  end
  for name, general in pairs(Fk.generals) do
    if Fk:canUseGeneral(name) and not trueNames[general.trueName] then
      table.insert(ret, name)
      trueNames[general.trueName] = true
    end
  end
  table.shuffle(ret)
  self.general_pile = ret
  return true
end

function Room:checkNoHuman(chkOnly)
  if #self.players == 0 then return end

  for _, p in ipairs(self.players) do
    -- TODO: trust
    if p.serverplayer:getState() == fk.Player_Online then
      return
    end
  end

  if not chkOnly then
    self:gameOver("")
  end
  return true
end

function Room:__tostring()
  return string.format("<Room #%d>", self.id)
end

--- 正式在这个房间中开始游戏。
---
--- 当这个函数返回之后，整个Room线程也宣告结束。
---@return nil
function Room:run()
  self.start_time = os.time()
  for _, p in fk.qlist(self.room:getPlayers()) do
    local player = ServerPlayer:new(p)
    player.room = self
    table.insert(self.players, player)
  end

  local mode = Fk.game_modes[self.settings.gameMode]
  local logic = (mode.logic and mode.logic() or GameLogic):new(self)
  self.logic = logic
  if mode.rule then logic:addTriggerSkill(mode.rule) end
  logic:start()
end

------------------------------------------------------------------------
-- getters/setters
------------------------------------------------------------------------

--- 根据角色id，获得那名角色本人
---@param id integer @ 角色的id
---@return ServerPlayer @ 这个id对应的ServerPlayer实例
function Room:getPlayerById(id)
  if not id then return nil end
  assert(type(id) == "number")

  for _, p in ipairs(self.players) do
    if p.id == id then
      return p
    end
  end

  return nil
end

--- 根据角色座位号，获得那名角色本人
---@param seat integer @ 角色的座位号
---@return ServerPlayer @ 这个座位号对应的ServerPlayer实例
function Room:getPlayerBySeat(seat)
  if not seat then return nil end

  assert(type(seat) == "number")
  for _, p in ipairs(self.players) do
    if p.seat == seat then
      return p
    end
  end

  return nil
end

--- 将房间中的角色按照行动顺序重新排序。
---@param playerIds integer[] @ 玩家id列表，这个数组会被这个函数排序
---@deprecated
function Room:sortPlayersByAction(playerIds, isTargetGroup)
  table.sort(playerIds, function(prev, next)
    local prevSeat = self:getPlayerById(isTargetGroup and prev[1] or prev).seat
    local nextSeat = self:getPlayerById(isTargetGroup and next[1] or next).seat

    return prevSeat < nextSeat
  end)

  if
    self.current and
    table.find(isTargetGroup and TargetGroup:getRealTargets(playerIds) or playerIds, function(id)
      return self:getPlayerById(id).seat >= self.current.seat
    end)
  then
    while self:getPlayerById(isTargetGroup and playerIds[1][1] or playerIds[1]).seat < self.current.seat do
      local toPlayerId = table.remove(playerIds, 1)
      table.insert(playerIds, toPlayerId)
    end
  end
end

---@param players ServerPlayer[]
function Room:sortByAction(players)
  table.sort(players, function(prev, next)
    return prev.seat < next.seat
  end)

  if self.current and table.find(players, function(p)
    return p.seat >= self.current.seat
  end) then
    while players[1].seat < self.current.seat do
      local toPlayerId = table.remove(players, 1)
      table.insert(players, toPlayerId)
    end
  end
end

---@param players ServerPlayer[]
---@return ServerPlayer[]
function Room:deadPlayerFilter(players)
  local newPlayerIds = {}
  for _, player in ipairs(players) do
    if player:isAlive() then
      table.insert(newPlayerIds, player)
    end
  end

  return newPlayerIds
end

--- 获得当前房间中的所有角色。
---
--- 如果按照座位排序，返回的数组的第一个元素是当前回合角色，并且按行动顺序进行排序。
---@param sortBySeat? boolean @ 是否按座位排序，默认是
---@return ServerPlayer[] @ 房间中角色的数组
function Room:getAllPlayers(sortBySeat)
  if not self.game_started then
    return { table.unpack(self.players) }
  end
  if sortBySeat == nil or sortBySeat then
    local current = self.current
    local temp = current.next
    local ret = {current}
    while temp ~= current do
      table.insert(ret, temp)
      temp = temp.next
    end

    return ret
  else
    return { table.unpack(self.players) }
  end
end

--- 获得所有存活角色，参看getAllPlayers
---@param sortBySeat? boolean @ 是否按座位排序，默认是
---@return ServerPlayer[]
function Room:getAlivePlayers(sortBySeat)
  if sortBySeat == nil or sortBySeat then
    local current = self.current
    local temp = current.next

    -- did not arrange seat, use default
    if temp == nil then
      return { table.unpack(self.players) }
    end
    local ret = current.dead and {} or {current}
    while temp ~= current do
      if not temp.dead then
        table.insert(ret, temp)
      end
      temp = temp.next
    end

    return ret
  else
    return { table.unpack(self.alive_players) }
  end
end

--- 获得除一名角色外的其他角色。
---@param player ServerPlayer @ 要排除的角色
---@param sortBySeat? boolean @ 是否按座位排序，默认是
---@param include_dead? boolean @ 是否要把死人也算进去？
---@return ServerPlayer[] @ 其他角色列表
function Room:getOtherPlayers(player, sortBySeat, include_dead)
  if sortBySeat == nil then
    sortBySeat = true
  end

  local players = include_dead and self:getAllPlayers(sortBySeat) or self:getAlivePlayers(sortBySeat)
  for _, p in ipairs(players) do
    if p.id == player.id then
      table.removeOne(players, player)
      break
    end
  end

  return players
end

--- 获得当前房间中的主公。
---
--- 由于某些游戏模式没有主公，该函数可能返回nil。
---@return ServerPlayer? @ 主公
function Room:getLord()
  local lord = self.players[1]
  if lord.role == "lord" then return lord end
  for _, p in ipairs(self.players) do
    if p.role == "lord" then return p end
  end

  return nil
end

--- 从摸牌堆中获取若干张牌。
---
--- 如果牌堆中没有足够的牌可以获得，那么会触发洗牌；还是不够的话，游戏就平局。
---@param num integer @ 要获得的牌的数量
---@param from? string @ 获得牌的位置，可以是 ``"top"`` 或者 ``"bottom"``，表示牌堆顶还是牌堆底
---@return integer[] @ 得到的id
function Room:getNCards(num, from)
  from = from or "top"
  assert(from == "top" or from == "bottom")
  if #self.draw_pile < num then
    self:shuffleDrawPile()
    if #self.draw_pile < num then
      self:sendLog{
        type = "#NoCardDraw",
        toast = true,
      }
      self:gameOver("")
    end
  end

  local i, j = 1, num
  if from == "bottom" then
    i = #self.draw_pile + 1 - num
    j = #self.draw_pile
  end
  -- local cardIds = {}
  -- for index = i, j, 1 do
  --   table.insert(cardIds, table.remove(self.draw_pile, i))
  -- end

  local cardIds = table.slice(self.draw_pile, i, j + 1)

  return cardIds
end

--- 将一名玩家的某种标记数量相应的值。
---
--- 在设置之后，会通知所有客户端也更新一下标记的值。之后的两个相同
---@param player ServerPlayer @ 要被更新标记的那个玩家
---@param mark string @ 标记的名称
---@param value any @ 要设为的值，其实也可以设为字符串
function Room:setPlayerMark(player, mark, value)
  player:setMark(mark, value)
  self:doBroadcastNotify("SetPlayerMark", json.encode{
    player.id,
    mark,
    value
  })
end

--- 将一名玩家的mark标记增加count个。
---@param player ServerPlayer @ 要加标记的玩家
---@param mark string @ 标记名称
---@param count? integer @ 要增加的数量，默认为1
function Room:addPlayerMark(player, mark, count)
  count = count or 1
  local num = player:getMark(mark)
  num = num or 0
  self:setPlayerMark(player, mark, math.max(num + count, 0))
end

--- 将一名玩家的mark标记减少count个。
---@param player ServerPlayer @ 要减标记的玩家
---@param mark string @ 标记名称
---@param count? integer  @ 要减少的数量，默认为1
function Room:removePlayerMark(player, mark, count)
  count = count or 1
  local num = player:getMark(mark)
  num = num or 0
  self:setPlayerMark(player, mark, math.max(num - count, 0))
end

--- 将一张卡牌的某种标记数量相应的值。
---
--- 在设置之后，会通知所有客户端也更新一下标记的值。之后的两个相同
---@param card Card @ 要被更新标记的那张牌
---@param mark string @ 标记的名称
---@param value any @ 要设为的值，其实也可以设为字符串
function Room:setCardMark(card, mark, value)
  card:setMark(mark, value)
  if not card:isVirtual() then
    self:doBroadcastNotify("SetCardMark", json.encode{
      card.id,
      mark,
      value
    })
  end
end

--- 将一张卡牌的mark标记增加count个。
---@param card Card @ 要被增加标记的那张牌
---@param mark string @ 标记名称
---@param count? integer @ 要增加的数量，默认为1
function Room:addCardMark(card, mark, count)
  count = count or 1
  local num = card:getMark(mark)
  num = num or 0
  self:setCardMark(card, mark, math.max(num + count, 0))
end

--- 将一名玩家的mark标记减少count个。
---@param card Card @ 要被减少标记的那张牌
---@param mark string @ 标记名称
---@param count? integer @ 要减少的数量，默认为1
function Room:removeCardMark(card, mark, count)
  count = count or 1
  local num = card:getMark(mark)
  num = num or 0
  self:setCardMark(card, mark, math.max(num - count, 0))
end

--- 设置角色的某个属性，并广播给所有人
---@param player ServerPlayer
---@param property string @ 属性名称
function Room:setPlayerProperty(player, property, value)
  player[property] = value
  self:broadcastProperty(player, property)
end

--- 将房间中某个tag设为特定值。
---
--- 当在编程中想在服务端搞点全局变量的时候哦，不要自己设置全局变量或者上值，而是应该使用room的tag。
---@param tag_name string @ tag名字
---@param value any @ 值
function Room:setTag(tag_name, value)
  self.tag[tag_name] = value
end

--- 获得某个tag的值。
---@param tag_name string @ tag名字
function Room:getTag(tag_name)
  return self.tag[tag_name]
end

--- 删除某个tag。
---@param tag_name string @ tag名字
function Room:removeTag(tag_name)
  self.tag[tag_name] = nil
end

function Room:setBanner(name, value)
  AbstractRoom.setBanner(self, name, value)
  self:doBroadcastNotify("SetBanner", json.encode{ name, value })
end

--- 设置房间的当前行动者
---@param player ServerPlayer
function Room:setCurrent(player)
  AbstractRoom.setCurrent(self, player)
  -- rawset(self, "current", player)
  self:doBroadcastNotify("SetCurrent", json.encode{ player and player.id or nil })
end

---@param player ServerPlayer
---@param general string
---@param changeKingdom? boolean
---@param noBroadcast? boolean
function Room:setPlayerGeneral(player, general, changeKingdom, noBroadcast)
  if Fk.generals[general] == nil then return end
  player.general = general
  player.gender = Fk.generals[general].gender
  self:notifyProperty(player, player, "general")
  self:broadcastProperty(player, "gender")

  if changeKingdom then
    player.kingdom = Fk.generals[general].kingdom
    if noBroadcast then
      self:notifyProperty(player, player, "kingdom")
    else
      self:broadcastProperty(player, "kingdom")
    end
  end
end

---@param player ServerPlayer
---@param general string
function Room:setDeputyGeneral(player, general)
  if Fk.generals[general] == nil then return end
  player.deputyGeneral = general
  self:notifyProperty(player, player, "deputyGeneral")
end

--- 为角色设置武将，并从武将池中抽出，若有隐匿技变为隐匿将。注意此时不会进行选择势力，请随后自行处理
---@param player ServerPlayer
---@param general string @ 主将名
---@param deputy? string @ 副将名
---@param broadcast? boolean @ 是否公示，默认否
function Room:prepareGeneral(player, general, deputy, broadcast)
  self:findGeneral(general)
  self:findGeneral(deputy)
  local skills = Fk.generals[general]:getSkillNameList()
  if Fk.generals[deputy] then
    table.insertTable(skills, Fk.generals[deputy]:getSkillNameList())
  end
  if table.find(skills, function (s) return Fk.skills[s].isHiddenSkill end) then
    self:setPlayerMark(player, "__hidden_general", general)
    if Fk.generals[deputy] then
      self:setPlayerMark(player, "__hidden_deputy", deputy)
      deputy = ""
    end
    general = "hiddenone"
  end
  player.general = general
  player.gender = Fk.generals[general].gender
  self:broadcastProperty(player, "gender")
  if Fk.generals[deputy] then
    player.deputyGeneral = deputy
  end
  player.kingdom = Fk.generals[general].kingdom
  for _, property in ipairs({"general","deputyGeneral","kingdom"}) do
    if broadcast then
      self:broadcastProperty(player, property)
    else
      self:notifyProperty(player, player, property)
    end
  end
end

function Room:toJsonObject(player)
  local o = AbstractRoom.toJsonObject(self)
  o.round_count = self:getBanner("RoundCount") or 0
  if player then
    o.you = player.id
  end
  return o
end

------------------------------------------------------------------------
-- 网络通信有关
------------------------------------------------------------------------

--- 向所有角色广播一名角色的某个property，让大家都知道
---@param player ServerPlayer @ 要被广而告之的那名角色
---@param property string @ 这名角色的某种属性，像是"hp"之类的，其实就是Player类的属性名
function Room:broadcastProperty(player, property)
  for _, p in ipairs(self.players) do
    self:notifyProperty(p, player, property)
  end
end

--- 将player的属性property告诉p。
---@param p ServerPlayer @ 要被告知相应属性的那名玩家
---@param player ServerPlayer @ 拥有那个属性的玩家
---@param property string @ 属性名称
function Room:notifyProperty(p, player, property)
  p:doNotify("PropertyUpdate", json.encode{
    player.id,
    property,
    player[property],
  })
end

--- 向多名玩家广播一条消息。
---@param command string @ 发出这条消息的消息类型
---@param jsonData string @ 消息的数据，一般是JSON字符串，也可以是普通字符串，取决于client怎么处理了
---@param players? ServerPlayer[] @ 要告知的玩家列表，默认为所有人
function Room:doBroadcastNotify(command, jsonData, players)
  players = players or self.players
  for _, p in ipairs(players) do
    p:doNotify(command, jsonData)
  end
end

--- 向某个玩家发起一次Request。
---@param player ServerPlayer @ 发出这个请求的目标玩家
---@param command string @ 请求的类型
---@param jsonData string @ 请求的数据
---@param wait? boolean @ 是否要等待答复，默认为true
---@return string @ 收到的答复，如果wait为false的话就返回nil
---@deprecated
function Room:doRequest(player, command, jsonData, wait)
  -- fk.qCritical("Room:doRequest is deprecated!")
  if wait == true then error("wait can't be true") end
  local request = Request:new(player, command)
  request.send_encode = false -- 因为参数已经json.encode过了，该死的兼容性
  request.receive_decode = false
  request.accept_cancel = true
  request:setData(player, jsonData)
  request:ask()
  return request.result[player.id]
end

--- 向多名玩家发出请求。
---@param command string @ 请求类型
---@param players? ServerPlayer[] @ 发出请求的玩家列表
---@param jsonData? string @ 请求数据
---@deprecated
function Room:doBroadcastRequest(command, players, jsonData)
  -- fk.qCritical("Room:doBroadcastRequest is deprecated!")
  players = players or self.players
  local request = Request:new(players, command)
  request.send_encode = false -- 因为参数已经json.encode过了
  request.receive_decode = false
  request.accept_cancel = true
  for _, p in ipairs(players) do
    request:setData(p, jsonData or p.request_data)
  end
  request:ask()
end

--- 向多名玩家发出竞争请求。
---
--- 他们都可以做出答复，但是服务器只认可第一个做出回答的角色。
---
--- 返回获胜的角色，可以通过属性获得回复的具体内容。
---@param command string @ 请求类型
---@param players ServerPlayer[] @ 要竞争这次请求的玩家列表
---@param jsonData string @ 请求数据
---@return ServerPlayer? @ 在这次竞争请求中获胜的角色，可能是nil
---@deprecated
function Room:doRaceRequest(command, players, jsonData)
  -- fk.qCritical("Room:doRaceRequest is deprecated!")
  players = players or self.players
  local request = Request:new(players, command, 1)
  request.send_encode = false -- 因为参数已经json.encode过了
  request.receive_decode = false
  for _, p in ipairs(players) do
    request:setData(p, jsonData or p.request_data)
  end
  request:ask()
  return request.winners[1]
end

--- 延迟一段时间。
---@param ms integer @ 要延迟的毫秒数
function Room:delay(ms)
  self.room:delay(math.ceil(ms))
  if self._test_disable_delay then return end
  coroutine.yield("__handleRequest", ms)
end

--- 延迟一段时间。界面上会显示所有人读条了。注意这个只能延迟多少秒。
---@param sec integer @ 要延迟的秒数
function Room:animDelay(sec)
  local req = Request:new(self.alive_players, "EmptyRequest")
  req.focus_text = ''
  req.timeout = sec
  req.no_time_waste_check = true
  req:ask()
end

--- 将焦点转移给一名或者多名角色，并广而告之。
---
--- 形象点说，就是在那些玩家下面显示一个“弃牌 思考中...”之类的烧条提示。
---@param players ServerPlayer | ServerPlayer[] @ 要获得焦点的一名或者多名角色
---@param command string @ 烧条的提示文字
---@param timeout integer? @ focus的烧条时长
function Room:notifyMoveFocus(players, command, timeout)
  if (players.class) then
    players = {players}
  end

  local ids = {}
  for _, p in ipairs(players) do
    table.insert(ids, p.id)
  end

  local tempSk = Fk.skills[command]
  if tempSk and #players == 1 then
    local p = players[1]
    if p:isFakeSkill(tempSk) then
      command = ""
      ids = table.map(self.alive_players, Util.IdMapper)
    end
  end

  self:doBroadcastNotify("MoveFocus", json.encode{
    ids,
    command,
    timeout
  })
end

--- 向战报中发送一条log。
---@param log LogMessage @ Log的实际内容
function Room:sendLog(log)
  self:doBroadcastNotify("GameLog", json.encode(log))
end

function Room:sendFootnote(ids, log)
  self:doBroadcastNotify("SetCardFootnote", json.encode{ ids, log })
end

function Room:sendCardVirtName(ids, name)
  self:doBroadcastNotify("SetCardVirtName", json.encode{ ids, name })
end

--- 播放某种动画效果给players看。
---@param type string @ 动画名字
---@param data any @ 这个动画附加的额外信息，在这个函数将会被转成json字符串
---@param players? ServerPlayer[] @ 要观看动画的玩家们，默认为全员
function Room:doAnimate(type, data, players)
  players = players or self.players
  data.type = type
  self:doBroadcastNotify("Animate", json.encode(data), players)
end

--- 在player脸上展示名为name的emotion动效。
---
--- 这就是“杀”、“闪”之类的那个动画。
---@param player ServerPlayer @ 被播放动画的那个角色
---@param name string @ emotion名字，可以是一个路径
function Room:setEmotion(player, name)
  self:doAnimate("Emotion", {
    player = player.id,
    emotion = name
  })
end

--- 在一张card上播放一段emotion动效。
---
--- 这张card必须在处理区里面，或者至少客户端觉得它在处理区。
---@param cid integer @ 被播放动效的那个牌的id
---@param name string @ emotion名字，可以是一个路径
function Room:setCardEmotion(cid, name)
  self:doAnimate("Emotion", {
    player = cid,
    emotion = name,
    is_card = true,
  })
end

--- 播放一个全屏大动画。可以自己指定qml文件路径和额外的信息。
---@param path string @ qml文件的路径，有默认值
---@param extra_data any @ 要传递的额外信息
function Room:doSuperLightBox(path, extra_data)
  path = path or "RoomElement/SuperLightBox.qml"
  self:doAnimate("SuperLightBox", {
    path = path,
    data = extra_data,
  })
end

--- 基本上是个不常用函数就是了
function Room:sendLogEvent(type, data, players)
  players = players or self.players
  data.type = type
  self:doBroadcastNotify("LogEvent", json.encode(data), players)
end

--- 播放技能的语音。
---@param skill_name nil @ 技能名
---@param index? integer @ 语音编号，默认为-1（也就是随机播放）
function Room:broadcastSkillInvoke(skill_name, index)
  fk.qCritical 'Room:broadcastSkillInvoke deprecated; use SPlayer:broadcastSkillInvoke'
  index = index or -1
  self:sendLogEvent("PlaySkillSound", {
    name = skill_name,
    i = index
  })
end

--- 播放一段音频。
---@param path string @ 音频文件路径
function Room:broadcastPlaySound(path)
  self:sendLogEvent("PlaySound", {
    name = path,
  })
end

--- 在player的脸上播放技能发动的特效。
---
--- 与此同时，在战报里面发一条“xxx发动了xxx”
---@param player ServerPlayer @ 发动技能的那个玩家
---@param skill_name string @ 技能名
---@param skill_type? string | AnimationType @ 技能的动画效果，默认是那个技能的anim_type
---@param tos? table<integer> @ 技能目标，填空则不声明
function Room:notifySkillInvoked(player, skill_name, skill_type, tos)
  local bigAnim = false
  if not skill_type then
    local skill = Fk.skills[skill_name]
    if not skill then skill_type = "" end

    if skill.frequency == Skill.Limited or skill.frequency == Skill.Wake then
      bigAnim = true
    end

    skill_type = skill.anim_type
  end

  if skill_type == "big" then bigAnim = true end

  if tos and #tos > 0 then
    self:sendLog{
      type = "#InvokeSkillTo",
      from = player.id,
      arg = skill_name,
      to = tos,
    }
  else
    self:sendLog{
      type = "#InvokeSkill",
      from = player.id,
      arg = skill_name,
    }
  end

  if not bigAnim then
    self:doAnimate("InvokeSkill", {
      name = skill_name,
      player = player.id,
      skill_type = skill_type,
    })
  else
    self:doAnimate("InvokeUltSkill", {
      name = skill_name,
      player = player.id,
      deputy = player.deputyGeneral and player.deputyGeneral ~= "" and table.contains(Fk.generals[player.deputyGeneral]:getSkillNameList(true), skill_name),
    })
    self:delay(2000)
  end
end

--- 播放从source指到targets的指示线效果。
---@param source integer @ 指示线开始的那个玩家的id
---@param targets integer[] @ 指示线目标玩家的id列表
function Room:doIndicate(source, targets)
  local target_group = {}
  for _, id in ipairs(targets) do
    table.insert(target_group, { id })
  end
  self:doAnimate("Indicate", {
    from = source,
    to = target_group,
  })
end

------------------------------------------------------------------------
-- 交互方法
------------------------------------------------------------------------

---@class AskToUseActiveSkillParams: AskToSkillInvokeParams
---@field cancelable? boolean @ 是否可以点取消
---@field no_indicate? boolean @ 是否不显示指示线
---@field extra_data? table @ 额外信息
---@field skip? boolean @ 是否跳过实际执行流程

--- 询问player是否要发动一个主动技。
---
--- 如果发动的话，那么会执行一下技能的onUse函数，然后返回选择的牌和目标等。
---@param player ServerPlayer @ 询问目标
---@param params AskToUseActiveSkillParams @ 各种变量
---@return boolean, table? @ 返回第一个值为是否成功发动，第二值为技能选牌、目标等数据
function Room:askToUseActiveSkill(player, params)
  params.prompt = params.prompt or ""
  params.cancelable = (params.cancelable == nil) and true or params.cancelable
  params.no_indicate = (params.no_indicate == nil) and true or params.no_indicate
  params.extra_data = params.extra_data or Util.DummyTable
  params.skip = params.skip or params.extra_data.skipUse
  ---@diagnostic disable-next-line assign-type-mismatch
  local skill = Fk.skills[params.skill_name] ---@type ActiveSkill | ViewAsSkill
  if not (skill and (skill:isInstanceOf(ActiveSkill) or skill:isInstanceOf(ViewAsSkill))) then
    print("Attempt ask for use non-active skill: " .. params.skill_name)
    return false
  end

  local command = "AskForUseActiveSkill"
  local data = {params.skill_name, params.prompt, params.cancelable, params.extra_data}

  Fk.currentResponseReason = params.extra_data.skillName
  local req = Request:new(player, command)
  req:setData(player, data)
  req.focus_text = params.extra_data.skillName or params.skill_name
  local result = req:getResult(player)
  Fk.currentResponseReason = nil

  if result == "" then
    return false
  end

  data = result
  local card = data.card
  local targets = data.targets
  local card_data = card
  local selected_cards = card_data.subcards
  local interaction
  if not params.no_indicate then
    self:doIndicate(player.id, targets)
  end

  if skill.interaction then
    interaction = data.interaction_data
    skill.interaction.data = interaction
  end

  if skill:isInstanceOf(ActiveSkill) and not params.skip then
    skill:onUse(self, SkillUseData:new {
      from = player,
      cards = selected_cards,
      tos = table.map(targets, Util.Id2PlayerMapper),
    })
  end

  return true, {
    cards = selected_cards,
    targets = table.map(targets, Util.Id2PlayerMapper),
    interaction = interaction
  }
end

Room.askToUseViewAsSkill = Room.askToUseActiveSkill

---@class AskToDiscardParams: AskToUseActiveSkillParams
---@field min_num integer @ 最小值
---@field max_num integer @ 最大值
---@field include_equip? boolean @ 能不能弃装备区？
---@field pattern? string @ 弃牌需要符合的规则
---@field skip? boolean @ 是否跳过弃牌（即只询问选择可以弃置的牌）

--- 询问一名角色弃牌。
---
--- 在这个函数里面牌已经被弃掉了（除非skipDiscard为true）。
---@param player ServerPlayer @ 弃牌角色
---@param params AskToDiscardParams @ 各种变量
---@return integer[] @ 弃掉的牌的id列表，可能是空的
function Room:askToDiscard(player, params)
  local skillName = params.skill_name
  local maxNum, minNum = params.max_num, params.min_num

  params.cancelable = (params.cancelable == nil) and true or params.cancelable
  params.no_indicate = params.no_indicate or false
  params.pattern = params.pattern or "."
  params.prompt = params.prompt or ("#AskForDiscard:::" .. maxNum .. ":" .. minNum)

  local canDiscards = table.filter(
    player:getCardIds{ Player.Hand, params.include_equip and Player.Equip or nil }, function(id)
      local checkpoint = true
      local card = Fk:getCardById(id)

      local status_skills = Fk:currentRoom().status_skills[ProhibitSkill] or Util.DummyTable
      for _, skill in ipairs(status_skills) do
        if skill:prohibitDiscard(player, card) then
          return false
        end
      end
      if skillName == "phase_discard" then
        status_skills = Fk:currentRoom().status_skills[MaxCardsSkill] or Util.DummyTable
        for _, skill in ipairs(status_skills) do
          if skill:excludeFrom(player, card) then
            return false
          end
        end
      end

      if params.pattern ~= "" then
        checkpoint = checkpoint and (Exppattern:Parse(params.pattern):match(card))
      end
      return checkpoint
    end
  )

  if minNum >= #canDiscards and not params.cancelable then
    if not params.skip then
      self:throwCard(canDiscards, skillName, player, player)
    end
    return canDiscards
  end

  local toDiscard = {}
  local data = {
    num = params.max_num,
    min_num = params.min_num,
    include_equip = params.include_equip,
    skillName = params.skill_name,
    pattern = params.pattern,
  }
  local _, ret = self:askToUseActiveSkill(player, {skill_name = "discard_skill", prompt = params.prompt, cancelable = params.cancelable, extra_data = data, no_indicate = params.no_indicate})

  if ret then
    toDiscard = ret.cards
  else
    if params.cancelable then return {} end
    toDiscard = table.random(canDiscards, minNum) ---@type integer[]
  end

  if not params.skip then
    self:throwCard(toDiscard, skillName, player, player)
  end

  return toDiscard
end

---@class AskToChoosePlayersParams: AskToUseActiveSkillParams
---@field targets ServerPlayer[] @ 可以选的目标范围
---@field min_num integer @ 最小值
---@field max_num integer @ 最大值
---@field target_tip_name? string @ 引用的选择目标提示的函数名

--- 询问一名玩家从targets中选择若干名玩家出来。
---@param player ServerPlayer @ 要做选择的玩家
---@param params AskToChoosePlayersParams @ 各种变量
---@return ServerPlayer[] @ 选择的玩家列表，可能为空
function Room:askToChoosePlayers(player, params)
  local maxNum, minNum = params.max_num, params.min_num
  if maxNum < 1 then
    return {}
  end
  params.cancelable = (params.cancelable == nil) and true or params.cancelable
  params.no_indicate = params.no_indicate or false

  local data = {
    targets = params.targets,
    num = maxNum,
    min_num = minNum,
    pattern = "",
    skillName = params.skill_name,
    targetTipName = params.target_tip_name,
    extra_data = params.extra_data,
  }
  local activeParams = { ---@type AskToUseActiveSkillParams
    skill_name = "choose_players_skill",
    prompt = params.prompt or "",
    cancelable = params.cancelable,
    extra_data = data,
    no_indicate = params.no_indicate
  }
  local _, ret = self:askToUseActiveSkill(player, activeParams)
  if ret then
    return ret.targets
  else
    if params.cancelable then
      return {}
    else
      return table.random(params.targets, minNum)
    end
  end
end

---@class AskToCardsParams: AskToUseActiveSkillParams
---@field min_num integer @ 最小值
---@field max_num integer @ 最大值
---@field include_equip? boolean @ 能不能选装备
---@field pattern? string @ 选牌规则
---@field expand_pile? string|integer[] @ 可选私人牌堆名称，或额外可选牌

--- 询问一名玩家选择自己的几张牌。
---
--- 与askForDiscard类似，但是不对选择的牌进行操作就是了。
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToCardsParams @ 各种变量
---@return integer[] @ 选择的牌的id列表，可能是空的
function Room:askToCards(player, params)
  local maxNum, minNum, expand_pile = params.max_num, params.min_num, params.expand_pile
  if maxNum < 1 then
    return {}
  end
  params.cancelable = (params.cancelable == nil) and true or params.cancelable
  params.no_indicate = params.no_indicate or false
  params.pattern = params.pattern or (params.include_equip and "." or ".|.|.|hand")
  params.prompt = params.prompt or ("#AskForCard:::" .. maxNum .. ":" .. minNum)

  local chosenCards = {}
  local data = {
    num = maxNum,
    min_num = minNum,
    include_equip = params.include_equip,
    skillName = params.skill_name,
    pattern = params.pattern,
    expand_pile = params.expand_pile,
  }
  local activeParams = { ---@type AskToUseActiveSkillParams
    skill_name = "choose_cards_skill",
    prompt = params.prompt,
    cancelable = params.cancelable,
    extra_data = data,
    no_indicate = params.no_indicate
  }
  local _, ret = self:askToUseActiveSkill(player, activeParams)
  if ret then
    chosenCards = ret.cards
  else
    if params.cancelable then return {} end
    local cards = player:getCardIds("he")
    if type(expand_pile) == "string" then
      table.insertTable(cards, player:getPile(expand_pile))
    elseif type(expand_pile) == "table" then
      table.insertTable(cards, expand_pile)
    end
    local exp = Exppattern:Parse(params.pattern)
    cards = table.filter(cards, function(cid)
      return exp:match(Fk:getCardById(cid))
    end)
    chosenCards = table.random(cards, minNum)
  end

  return chosenCards
end

---@class AskToChooseCardAndPlayersParams: AskToChoosePlayersParams
---@field pattern? string @ 选牌规则

--- 询问玩家选择1张牌和若干名角色。
---
--- 返回两个值，第一个是选择的目标列表，第二个是选择的那张牌的id
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToChooseCardAndPlayersParams @ 各种变量
---@return ServerPlayer[], integer?
function Room:askToChooseCardAndPlayers(player, params)
  local maxNum, minNum = params.max_num, params.min_num
  if maxNum < 1 then
    return {}
  end
  params.cancelable = (params.cancelable == nil) and true or params.cancelable
  params.no_indicate = params.no_indicate or false
  params.pattern = params.pattern or "."

  local pcards = table.filter(player:getCardIds({ Player.Hand, Player.Equip }), function(id)
    local c = Fk:getCardById(id)
    return c:matchPattern(params.pattern)
  end)
  if #pcards == 0 and not params.cancelable then return {} end

  local data = {
    targets = params.targets,
    num = maxNum,
    min_num = minNum,
    pattern = params.pattern,
    skillName = params.skill_name,
    targetTipName = params.target_tip_name,
    extra_data = params.extra_data,
  }
  local activeParams = { ---@type AskToUseActiveSkillParams
    skill_name = "choose_players_skill",
    prompt = params.prompt or "",
    cancelable = params.cancelable,
    extra_data = data,
    no_indicate = params.no_indicate
  }
  local _, ret = self:askToUseActiveSkill(player, activeParams)
  if ret then
    return ret.targets, ret.cards[1]
  else
    if params.cancelable then
      return {}
    else
      return table.random(params.targets, minNum), table.random(pcards)
    end
  end
end

---@class AskToChooseCardsAndPlayersParams: AskToChooseCardAndPlayersParams
---@field min_card_num integer @ 选卡牌最小值
---@field max_card_num integer @ 选卡牌最大值
---@field expand_pile? string|integer[] @ 可选私人牌堆名称，或额外可选牌

--- 询问玩家选择X张牌和Y名角色。
---
--- 返回两个值，第一个是选择目标id列表，第二个是选择的牌id列表，第三个是否按了确定
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToChooseCardsAndPlayersParams @ 各种变量
---@return ServerPlayer[], integer[], boolean @ 第一个是选择目标id列表，第二个是选择的牌id列表，第三个是否按了确定
function Room:askToChooseCardsAndPlayers(player, params)
  local maxTargetNum, minTargetNum, maxCardNum, minCardNum = params.max_num, params.min_num, params.max_card_num, params.min_card_num
  params.cancelable = (params.cancelable == nil) and true or params.cancelable
  params.no_indicate = params.no_indicate or false
  params.pattern = params.pattern or "."

  local pcards = table.filter(player:getCardIds({ Player.Hand, Player.Equip }), function(id)
    local c = Fk:getCardById(id)
    return c:matchPattern(params.pattern)
  end)
  if #pcards < minCardNum and not params.cancelable then return {}, {}, false end

  local data = {
    targets = params.targets,
    max_t_num = maxTargetNum,
    min_t_num = minTargetNum,
    max_c_num = maxCardNum,
    min_c_num = minCardNum,
    pattern = params.pattern,
    skillName = params.skill_name,
    targetTipName = params.target_tip_name,
    extra_data = params.extra_data,
    expand_pile = params.expand_pile or (params.extra_data and params.extra_data.expand_pile),
  }
  local activeParams = { ---@type AskToUseActiveSkillParams
    skill_name = "ex__choose_skill",
    prompt = params.prompt or "",
    cancelable = params.cancelable,
    extra_data = data,
    no_indicate = params.no_indicate
  }
  local success, ret = self:askToUseActiveSkill(player, activeParams)
  if ret then
    return ret.targets, ret.cards, success
  else
    if params.cancelable then
      return {}, {}, false
    else
      return table.random(params.targets, minTargetNum), table.random(pcards, minCardNum), false
    end
  end
end

---@class AskToYijiParams: AskToChoosePlayersParams
---@field cards? integer[] @ 要分配的卡牌。默认拥有的所有牌
---@field expand_pile? string|integer[] @ 可选私人牌堆名称，或额外可选牌
---@field single_max? integer|table @ 限制每人能获得的最大牌数。输入整数或(以角色id为键以整数为值)的表
---@field skip? boolean @ 是否跳过移动。默认不跳过

--- 询问将卡牌分配给任意角色。
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToYijiParams @ 各种变量
---@return table<integer, integer[]> @ 返回一个表，键为角色id，值为分配给其的牌id数组
function Room:askToYiji(player, params)
  local targets = params.targets or self.alive_players
  self:sortByAction(targets)
  targets = table.map(targets, Util.IdMapper)
  local cards = params.cards or player:getCardIds("he")
  local _cards = table.simpleClone(cards)
  params.skill_name = params.skill_name or "distribution_select_skill"
  params.min_num = params.min_num or 0
  params.max_num = params.max_num or #cards
  local skillName, minNum, maxNum, single_max, expand_pile = params.skill_name,
    params.min_num, params.max_num, params.single_max, params.expand_pile

  local list = {}
  for _, pid in ipairs(targets) do
    list[pid] = {}
  end
  local toStr = function(int) return string.format("%d", int) end
  local residueMap = {}
  if type(single_max) == "table" then
    for pid, v in pairs(single_max) do
      residueMap[toStr(pid)] = v
    end
  end
  local residue_sum = 0
  local residue_num = type(single_max) == "number" and single_max or 9999
  for _, pid in ipairs(targets) do
    residueMap[toStr(pid)] = residueMap[toStr(pid)] or residue_num
    residue_sum = residue_sum + residueMap[toStr(pid)]
  end
  minNum = math.min(minNum, #_cards, residue_sum)
  maxNum = math.min(maxNum, #_cards, residue_sum)
  local data = {
    cards = _cards,
    max_num = maxNum,
    targets = targets,
    residued_list = residueMap,
    expand_pile = expand_pile
  }

  while maxNum > 0 and #_cards > 0 do
    data.max_num = maxNum
    local prompt = params.prompt or ("#AskForDistribution:::"..minNum..":"..maxNum)
    local activeParams = { ---@type AskToUseActiveSkillParams
      skill_name = "distribution_select_skill",
      prompt = prompt,
      cancelable = minNum == 0,
      extra_data = data,
      no_indicate = true
    }
    local success, dat = self:askToUseActiveSkill(player, activeParams)
    if success and dat then
      local to = dat.targets[1]
      local give_cards = dat.cards
      for _, id in ipairs(give_cards) do
        table.insert(list[to], id)
        table.removeOne(_cards, id)
        local p = self:getPlayerById(to)
        self:setCardMark(Fk:getCardById(id), "@DistributionTo",
          Fk:translate(p.general == "anjiang" and "seat#" .. tostring(p.seat) or p.general))
      end
      minNum = math.max(0, minNum - #give_cards)
      maxNum = maxNum - #give_cards
      residueMap[toStr(to)] = residueMap[toStr(to)] - #give_cards
    else
      break
    end
  end

  for _, id in ipairs(cards) do
    self:setCardMark(Fk:getCardById(id), "@DistributionTo", 0)
  end
  for _, pid in ipairs(targets) do
    if minNum == 0 or #_cards == 0 then break end
    local num = math.min(residueMap[toStr(pid)] or 0, minNum, #_cards)
    if num > 0 then
      for i = num, 1, -1 do
        local c = table.remove(_cards, i)
        table.insert(list[pid], c)
        minNum = minNum - 1
      end
    end
  end
  if not params.skip then
    self:doYiji(list, player.id, skillName)
  end

  return list
end

---@class AskToChooseGeneralParams
---@field generals string[] @ 可选武将
---@field n integer @ 可选数量，默认为1
---@field no_convert? boolean @ 可否同名替换，默认可

--- 询问玩家选择一名武将。
---@param player ServerPlayer @ 询问目标
---@param params AskToChooseGeneralParams @ 各种变量
---@return string|string[] @ 选择的武将
function Room:askToChooseGeneral(player, params)
  local command = "AskForGeneral"

  params.n = params.n or 1
  local n, generals = params.n, params.generals
  if #generals == n then return n == 1 and generals[1] or generals end
  local defaultChoice = table.random(generals, n)

  local req = Request:new(player, command)
  local data = { generals, n, params.no_convert }
  req:setData(player, data)
  req:setDefaultReply(player, defaultChoice)
  local choices = req:getResult(player)
  if #choices == 1 then return choices[1] end
  return choices
end

--- 询问玩家若为神将、双势力需选择一个势力。
---@param players? ServerPlayer[] @ 询问目标
function Room:askToChooseKingdom(players)
  players = players or self.alive_players
  local specialKingdomPlayers = table.filter(players, function(p)
    return Fk.generals[p.general].subkingdom or #Fk:getKingdomMap(p.kingdom) > 0
  end)

  if #specialKingdomPlayers > 0 then
    local req = Request:new(specialKingdomPlayers, "AskForChoice")
    req.focus_text = "AskForKingdom"
    req.receive_decode = false
    for _, p in ipairs(specialKingdomPlayers) do
      local allKingdoms = {}
      local curGeneral = Fk.generals[p.general]
      if curGeneral.subkingdom then
        allKingdoms = { curGeneral.kingdom, curGeneral.subkingdom }
      else
        allKingdoms = Fk:getKingdomMap(p.kingdom)
      end
      if #allKingdoms > 0 then
        req:setData(p, { allKingdoms, allKingdoms, "AskForKingdom", "#ChooseInitialKingdom" })
        req:setDefaultReply(p, allKingdoms[1])
      end
    end

    for _, p in ipairs(specialKingdomPlayers) do
      p.kingdom = req:getResult(p)
      self:notifyProperty(p, p, "kingdom")
    end
  end
end

---@class AskToChooseCardParams: AskToUseActiveSkillParams
---@field target ServerPlayer @ 被选牌的人
---@field flag string | table @ 用"hej"三个字母的组合表示能选择哪些区域, h 手牌区, e - 装备区, j - 判定区
---@field skill_name string @ 原因，一般是技能名

--- 询问player，选择target的一张牌。
---@param player ServerPlayer @ 要被询问的人
---@param params AskToChooseCardParams @ 各种变量
---@return integer @ 选择的卡牌id
function Room:askToChooseCard(player, params)
  local command = "AskForCardChosen"
  params.prompt = params.prompt or ""
  local target, flag, reason, prompt = params.target, params.flag, params.skill_name, params.prompt
  local data = {target.id, flag, reason, prompt}
  local req = Request:new(player, command)
  req:setData(player, data)
  local result = req:getResult(player)

  if result == "" then
    local areas = {}
    local handcards
    if type(flag) == "string" then
      if string.find(flag, "h") then table.insert(areas, Player.Hand) end
      if string.find(flag, "e") then table.insert(areas, Player.Equip) end
      if string.find(flag, "j") then table.insert(areas, Player.Judge) end
      handcards = target:getCardIds(areas)
    else
      handcards = {}
      for _, t in ipairs(flag.card_data) do
        table.insertTable(handcards, t[2])
      end
    end
    if #handcards == 0 then return end
    result = handcards[math.random(1, #handcards)]
  end

  if result == -1 then
    local handcards = target:getCardIds(Player.Hand)
    if #handcards == 0 then return end
    result = table.random(handcards)
  end

  return result
end

---@class AskToPoxiParams
---@field poxi_type string @ poxi关键词
---@field data any @ 牌堆信息
---@field extra_data any @ 额外信息
---@field cancelable? boolean @ 是否可取消

--- 谋askForCardsChosen，需使用Fk:addPoxiMethod定义好方法
---
--- 选卡规则和返回值啥的全部自己想办法解决，data填入所有卡的列表（类似ui.card_data）
---
--- 注意一定要返回一个表，毕竟本质上是选卡函数
---@param player ServerPlayer @ 要被询问的人
---@param params AskToPoxiParams @ 各种变量
---@return integer[] @ 选择的牌ID数组
function Room:askToPoxi(player, params)
  params.cancelable = (params.cancelable == nil) and true or params.cancelable
  local poxi = Fk.poxi_methods[params.poxi_type]
  if not poxi then return {} end

  local command = "AskForPoxi"
  local req = Request:new(player, command)
  req.focus_text = params.poxi_type
  req:setData(player, {
    type = params.poxi_type,
    data = params.data,
    extra_data = params.extra_data,
    cancelable = params.cancelable
  })
  local result = req:getResult(player)

  if result == "" then
    return poxi.default_choice(params.data, params.extra_data)
  else
    return poxi.post_select(result, params.data, params.extra_data)
  end
end

---@class AskToChooseCardsParams: AskToChooseCardParams
---@field min integer @ 最小选牌数
---@field max integer @ 最大选牌数

--- 完全类似askForCardChosen，但是可以选择多张牌。
--- 相应的，返回的是id的数组而不是单个id。
---@param player ServerPlayer @ 要被询问的人
---@param params AskToChooseCardsParams @ 各种变量
---@return integer[] @ 选择的id
function Room:askToChooseCards(player, params)
  local target, flag, reason, prompt = params.target, params.flag, params.skill_name, params.prompt
  local min, max = params.min, params.max
  if min == 1 and max == 1 then
    return { self:askToChooseCard(player, params) }
  end

  local cards
  if type(flag) == "string" then
    cards = target:getCardIds(flag)
  else
    cards = {}
    for _, t in ipairs(flag.card_data) do
      table.insertTable(cards, t[2])
    end
  end
  if #cards <= min then return cards end

  local data = {
    to = target.id,
    min = min,
    max = max,
    skillName = reason,
    prompt = prompt,
  }
  local visible_data = {}
  local cards_data = {}
  if type(flag) == "string" then
    local handcards = target:getCardIds(Player.Hand)
    local equips = target:getCardIds(Player.Equip)
    local judges = target:getCardIds(Player.Judge)
    if string.find(flag, "h") and #handcards > 0 then
      table.insert(cards_data, {"$Hand", handcards})
      for _, id in ipairs(handcards) do
        if not player:cardVisible(id) then
          visible_data[tostring(id)] = false
        end
      end
      if next(visible_data) == nil then visible_data = nil end
      data.visible_data = visible_data
    end
    if string.find(flag, "e") and #equips > 0 then
      table.insert(cards_data, {"$Equip", equips})
    end
    if string.find(flag, "j") and #judges > 0 then
      table.insert(cards_data, {"$Judge", judges})
    end
  else
    for _, t in ipairs(flag.card_data) do
      table.insert(cards_data, t)
    end
  end

  local poxiParams = { ---@type askToPoxiParams
    poxi_type = "AskForCardsChosen",
    data = cards_data,
    extra_data = data,
    cancelable = false
  }

  local ret = self:askToPoxi(player, poxiParams)
  local new_ret = table.filter(ret, function(id) return id ~= -1 end)
  local hidden_num = #ret - #new_ret
  if hidden_num > 0 then
    table.insertTable(new_ret,
    table.random(target:getCardIds(Player.Hand), hidden_num))
  end
  return new_ret
end

---@class AskToChoiceParams
---@field choices string[] @ 可选选项列表
---@field skill_name? string @ 技能名
---@field prompt? string @ 提示信息
---@field detailed? boolean @ 选项是否详细描述
---@field all_choices? string[] @ 所有选项（不可选变灰）
---@field cancelable? boolean @ 是否可以点取消

--- 询问一名玩家从众多选项中选择一个。
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToChoiceParams @ 各种变量
---@return string @ 选择的选项
function Room:askToChoice(player, params)
  if #params.choices == 1 and not params.all_choices then return params.choices[1] end
  assert(not params.all_choices or table.every(params.choices, function(c) return table.contains(params.all_choices, c) end))
  local command = "AskForChoice"
  params.prompt = params.prompt or ""
  params.all_choices = params.all_choices or params.choices

  local req = Request:new(player, command)
  req.focus_text = params.skill_name
  req.receive_decode = false -- 这个不用decode
  req:setData(player, {
    params.choices, params.all_choices, params.skill_name, params.prompt, params.detailed
  })
  local result = req:getResult(player)

  if result == "" then
    if table.contains(params.choices, "Cancel") then
      result = "Cancel"
    else
      result = params.choices[1]
    end
  end
  return result
end

---@class AskToChoicesParams: AskToChoiceParams
---@field min_num number @ 最少选择项数
---@field max_num number @ 最多选择项数

--- 询问一名玩家从众多选项中勾选任意项。
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToChoicesParams @ 各种变量
---@return string[] @ 选择的选项
function Room:askToChoices(player, params)
  local minNum, maxNum = params.min_num, params.max_num
  params.cancelable = (params.cancelable == nil) and true or params.cancelable
  if #params.choices <= minNum and not params.all_choices and not params.cancelable then return params.choices end
  assert(minNum <= maxNum)
  assert(not params.all_choices or table.every(params.choices, function(c) return table.contains(params.all_choices, c) end))

  local command = "AskForChoices"
  params.skill_name = params.skill_name or ""
  params.prompt = params.prompt or ""
  params.all_choices = params.all_choices or params.choices
  params.detailed = params.detailed or false

  local req = Request:new(player, command)
  req.focus_text = params.skill_name
  req:setData(player, {
    params.choices, params.all_choices, {minNum, maxNum}, params.cancelable, params.skill_name, params.prompt, params.detailed
  })
  local result = req:getResult(player)
  if result == "" then
    if params.cancelable then
      return {}
    else
      return table.random(params.choices, math.min(minNum, #params.choices))
    end
  end
  return result
end

---@class AskToSkillInvokeParams
---@field skill_name string @ 烧条时显示的技能名
---@field prompt? string @ 提示信息

--- 询问玩家是否发动技能。
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToSkillInvokeParams @ 各种变量
---@return boolean @ 是否发动
function Room:askToSkillInvoke(player, params)
  local command = "AskForSkillInvoke"
  local req = Request:new(player, command)
  req.focus_text = params.skill_name
  req.receive_decode = false -- 这个返回的都是"1" 不用decode
  req:setData(player, { params.skill_name, params.prompt })
  return req:getResult(player) ~= ""
end

---@class AskToArrangeCardsParams: AskToSkillInvokeParams
---@field card_map any @ { "牌堆1卡表", "牌堆2卡表", …… }
---@field prompt? string @ 操作提示
---@field box_size? integer @ 数值对应卡牌平铺张数的最大值，为0则有单个卡位，每张卡占100单位长度，默认为7
---@field max_limit? integer[] @ 每一行牌上限 { 第一行, 第二行，…… }，不填写则不限
---@field min_limit? integer[] @ 每一行牌下限 { 第一行, 第二行，…… }，不填写则不限
---@field free_arrange? boolean @ 是否允许自由排列第一行卡的位置，默认不能
---@field pattern? string @ 控制第一行卡牌是否可以操作，不填写默认均可操作
---@field poxi_type? string @ 控制每张卡牌是否可以操作、确定键是否可以点击，不填写默认均可操作
---@field default_choice? table[] @ 超时的默认响应值，在带poxi_type时需要填写

--- 询问玩家在自定义大小的框中排列卡牌（观星、交换、拖拽选牌）
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToArrangeCardsParams @ 各种变量
---@return table[] @ 排列后的牌堆结果
function Room:askToArrangeCards(player, params)
  params.prompt = params.prompt or ""
  local areaNames = {}
  if type(params.card_map[1]) == "number" then
    params.card_map = {params.card_map}
  else
    for i = #params.card_map, 1, -1 do
      if type(params.card_map[i]) == "string" then
        table.insert(areaNames, 1, params.card_map[i])
        table.remove(params.card_map, i)
      end
    end
  end
  if #areaNames == 0 then
    areaNames = {params.skill_name, "toObtain"}
  end
  local cardMap = params.card_map
  params.box_size = params.box_size or 7
  params.max_limit = params.max_limit or {#cardMap[1], #cardMap > 1 and #cardMap[2] or #cardMap[1]}
  params.min_limit = params.min_limit or {0, 0}
  for _ = #cardMap + 1, #params.min_limit, 1 do
    table.insert(cardMap, {})
  end
  params.pattern = params.pattern or "."
  params.poxi_type = params.poxi_type or ""
  local command = "AskForArrangeCards"
  local data = {
    cards = cardMap,
    names = areaNames,
    prompt = params.prompt,
    size = params.box_size,
    capacities = params.max_limit,
    limits = params.min_limit,
    is_free = params.free_arrange or false,
    pattern = params.pattern or ".",
    poxi_type = params.poxi_type or "",
    cancelable = ((params.pattern ~= "." or params.poxi_type ~= "") and (params.default_choice == nil))
  }
  local req = Request:new(player, command)
  req:setData(player, data)
  local result = req:getResult(player)
  -- local result = player.room:askForCustomDialog(player, skillname,
  -- "RoomElement/ArrangeCardsBox.qml", {
  --   cardMap, prompt, box_size, max_limit, min_limit, free_arrange or false, areaNames,
  --   pattern or ".", poxi_type or "", ((pattern ~= "." or poxi_type ~= "") and (default_choice == nil))
  -- })
  if result == "" then
    if params.default_choice then return params.default_choice end
    for j = 1, #params.min_limit, 1 do
      if #cardMap[j] < params.min_limit[j] then
        local cards = {table.connect(table.unpack(cardMap))}
        if #params.min_limit > 1 then
          for i = 2, #params.min_limit, 1 do
            table.insert(cards, {})
            if #cards[i] < params.min_limit[i] then
              for _ = 1, params.min_limit[i] - #cards[i], 1 do
                table.insert(cards[i], table.remove(cards[1], #cards[1] + #cards[i] - params.min_limit[i] + 1))
              end
            end
          end
          if #cards[1] > params.max_limit[1] then
            for i = 2, #params.max_limit, 1 do
              while #cards[i] < params.max_limit[i] do
                table.insert(cards[i], table.remove(cards[1], params.max_limit[1] + 1))
                if #cards[1] == params.max_limit[1] then return cards end
              end
            end
          end
        end
        return cards
      end
    end
    return cardMap
  end
  return result
end

---@class AskToGuanxingParams
---@field cards integer[] @ 可以被观星的卡牌id列表
---@field top_limit? integer[] @ 置于牌堆顶的牌的限制(下限,上限)，不填写则不限
---@field bottom_limit? integer[] @ 置于牌堆底的牌的限制(下限,上限)，不填写则不限
---@field skill_name? string @ 烧条时显示的技能名
---@field title? string @ 观星框的标题
---@field skip? boolean @ 是否进行放置牌操作
---@field area_names? string[] @ 左侧提示信息

--- 询问玩家对若干牌进行观星。
---
--- 观星完成后，相关的牌会被置于牌堆顶或者牌堆底。所以这些cards最好不要来自牌堆，一般先用getNCards从牌堆拿出一些牌。
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToGuanxingParams @ 各种变量
---@return table<"top"|"bottom", integer[]> @ 观星后的牌堆结果
function Room:askToGuanxing(player, params)
  -- 这一大堆都是来提前报错的
  local cards, top_limit, bottom_limit, customNotify, noPut = params.cards, params.top_limit, params.bottom_limit, params.prompt, params.skip
  local leng = #cards
  top_limit = top_limit or { 0, leng }
  bottom_limit = bottom_limit or { 0, leng }
  if #top_limit > 0 then
    assert(top_limit[1] >= 0 and top_limit[2] >= 0, "limits error: The lower limit should be greater than 0")
    assert(top_limit[1] <= top_limit[2], "limits error: The upper limit should be less than the lower limit")
  end
  if #bottom_limit > 0 then
    assert(bottom_limit[1] >= 0 and bottom_limit[2] >= 0, "limits error: The lower limit should be greater than 0")
    assert(bottom_limit[1] <= bottom_limit[2], "limits error: The upper limit should be less than the lower limit")
  end
  if #top_limit > 0 and #bottom_limit > 0 then
    assert(leng >= top_limit[1] + bottom_limit[1] and leng <= top_limit[2] + bottom_limit[2], "limits Error: No enough space")
  end
  if params.area_names then
    assert(#params.area_names > 0, "area_names error: Should have elements")
  else
    params.area_names =  { "Top", "Bottom" }
  end
  params.prompt = params.prompt or ""
  local command = "AskForGuanxing"
  local max_top = top_limit[2]
  local card_map = {}
  if max_top > 0 then
    table.insert(card_map, table.slice(cards, 1, max_top + 1))
  end
  if max_top < leng then
    table.insert(card_map, table.slice(cards, max_top + 1))
  end
  local data = {
    prompt = params.prompt,
    is_free = true,
    cards = card_map,
    min_top_cards = top_limit[1],
    max_top_cards = top_limit[2],
    min_bottom_cards = bottom_limit[1],
    max_bottom_cards = bottom_limit[2],
    top_area_name = params.area_names[1],
    bottom_area_name = params.area_names[2],
  }

  local req = Request:new(player, command)
  req.focus_text = customNotify
  req:setData(player, data)
  local result = req:getResult(player)
  local top, bottom
  if result ~= "" then
    local d = result
    if top_limit[2] == 0 then
      top = Util.DummyTable
      bottom = d[1]
    else
      top = d[1]
      bottom = d[2] or Util.DummyTable
    end
  else
    local pos = math.min(top_limit[2], leng - bottom_limit[1])
    top = table.slice(cards, 1, pos + 1)
    bottom = table.slice(cards, pos + 1)
  end

  if not noPut then
    for i = #top, 1, -1 do
      table.removeOne(self.draw_pile, top[i])
      table.insert(self.draw_pile, 1, top[i])
    end
    for i = 1, #bottom, 1 do
      table.removeOne(self.draw_pile, bottom[i])
      table.insert(self.draw_pile, bottom[i])
    end

    self:syncDrawPile()
    self:sendLog{
      type = "#GuanxingResult",
      from = player.id,
      arg = #top,
      arg2 = #bottom,
    }
  end

  return { top = top, bottom = bottom }
end

---@class AskToExchangeParams
---@field piles integer[][] @ 卡牌id列表的列表，也就是……几堆牌堆的集合
---@field piles_name? string[] @ 牌堆名，不足部分替换为“牌堆1、牌堆2...”
---@field skill_name? string @ 烧条时显示的技能名

--- 询问玩家任意交换几堆牌堆。
---
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToExchangeParams @ 各种变量
---@return integer[][] @ 交换后的结果
function Room:askToExchange(player, params)
  local piles, customNotify = params.piles, params.prompt
  local command = "AskForExchange"
  params.piles_name = params.piles_name or Util.DummyTable
  local x = #piles - #params.piles_name
  if x > 0 then
    for i = 1, x, 1 do
      table.insert(params.piles_name, Fk:translate("Pile") .. i)
    end
  elseif x < 0 then
    params.piles_name = table.slice(params.piles_name, 1, #piles + 1)
  end
  local data = {
    piles = piles,
    piles_name = params.piles_name,
  }

  local req = Request:new(player, command)
  req.focus_text = customNotify
  req:setData(player, data)
  local result = req:getResult(player)
  if result ~= "" then
    return result
  else
    return piles
  end
end


-- 获取使用牌的合法额外目标（【借刀杀人】等带副目标的卡牌除外）
---@param data UseCardDataSpec @ 使用事件的data
---@param bypass_distances boolean? @ 是否无距离关系的限制
---@param use_AimGroup boolean? @ 某些场合需要使用AimGroup，by smart Ho-spair
---@return integer[] @ 返回满足条件的player的id列表
function Room:getUseExtraTargets(data, bypass_distances, use_AimGroup)
  if not (data.card.type == Card.TypeBasic or data.card:isCommonTrick()) then return {} end
  if data.card.skill:getMinTargetNum() > 1 then return {} end --stupid collateral
  local tos = {}
  local current_targets = use_AimGroup and AimGroup:getAllTargets(data.tos) or TargetGroup:getRealTargets(data.tos)
  for _, p in ipairs(self.alive_players) do
    if not table.contains(current_targets, p.id) and not self:getPlayerById(data.from):isProhibited(p, data.card) then
      if data.card.skill:modTargetFilter(self:getPlayerById(data.from), p, {}, data.card, not bypass_distances) then
        table.insert(tos, p.id)
      end
    end
  end
  return tos
end

--- 抽个武将
---
--- 同getNCards，抽出来就没有了，所以记得放回去。
---@param n number @ 数量
---@param position? string @位置，top/bottom，默认top
---@return string[] @ 武将名数组
function Room:getNGenerals(n, position)
  position = position or "top"
  assert(position == "top" or position == "bottom")

  local generals = {}
  while n > 0 do

    local index = position == "top" and 1 or #self.general_pile
    table.insert(generals, table.remove(self.general_pile, index))

    n = n - 1
  end

  if #generals < 1 then
    self:sendLog{
      type = "#NoGeneralDraw",
      toast = true,
    }
    self:gameOver("")
  end
  return generals
end

--- 把武将牌塞回去（……）
---@param g string[] @ 武将名数组
---@param position? string @位置，top/bottom/random，默认random
---@return boolean @ 是否成功
function Room:returnToGeneralPile(g, position)
  position = position or "random"
  assert(position == "top" or position == "bottom" or position == "random")
  if position == "bottom" then
    table.insertTable(self.general_pile, g)
  elseif position == "top" then
    while #g > 0 do
      table.insert(self.general_pile, 1, table.remove(g))
    end
  elseif position == "random" then
    while #g > 0 do
      table.insert(self.general_pile, math.random(1, #self.general_pile),
                   table.remove(g))
    end
  end

  return true
end

--- 抽特定名字的武将（抽了就没了）
---@param name string? @ 武将name，如找不到则查找truename，再找不到则返回nil
---@return string? @ 抽出的武将名
function Room:findGeneral(name)
  if not Fk.generals[name] then return nil end
  for i, g in ipairs(self.general_pile) do
    if g == name or Fk.generals[g].trueName == Fk.generals[name].trueName then
      return table.remove(self.general_pile, i)
    end
  end
  return nil
end

--- 自上而下抽符合特定情况的N个武将（抽了就没了）
---@param func fun(name: string):any @ 武将筛选函数
---@param n? integer @ 抽取数量，数量不足则直接抽干净
---@return string[] @ 武将组合，可能为空
function Room:findGenerals(func, n)
  n = n or 1
  local ret = {}
  local index = 1
  while #ret < n and index <= #self.general_pile do
    if func(self.general_pile[index]) then
      table.insert(ret, table.remove(self.general_pile, index))
    else
      index = index + 1
    end
  end
  return ret
end

--- 将从Request获得的数据转化为UseCardData，或执行主动技的onUse部分
--- 一般DIY用不到的内部函数
---@param player ServerPlayer
---@return UseCardDataSpec?
function Room:handleUseCardReply(player, data)
  local card = data.card
  local targets = data.targets or {}
  if type(card) == "table" then
    local card_data = card
    local skill = Fk.skills[card_data.skill]
    local selected_cards = card_data.subcards
    if skill.interaction then skill.interaction.data = data.interaction_data end
    if skill:isInstanceOf(ActiveSkill) then
      ---@cast skill ActiveSkill
      self:useSkill(player, skill, function()
        skill:onUse(self, SkillUseData:new {
          from = player,
          cards = selected_cards,
          tos = table.map(targets, Util.Id2PlayerMapper),
        })
      end, {tos = table.map(targets, Util.Id2PlayerMapper), cards = selected_cards, cost_data = {}})
      return nil
    elseif skill:isInstanceOf(ViewAsSkill) then
      ---@cast skill ViewAsSkill
      Self = player
      local c = skill:viewAs(player, selected_cards)
      if c then
        ---@type UseCardDataSpec
        local use = {
          from = player,
          tos = {},
          card = c,
        }
        for _, targetId in ipairs(targets) do
          table.insert(use.tos, self:getPlayerById(targetId))
        end

        self:useSkill(player, skill, Util.DummyFunc)
        use.attachedSkillAndUser = { skillName = skill.name, user = player.id }

        local rejectSkillName = skill:beforeUse(player, use)
        if type(rejectSkillName) == "string" then
          return rejectSkillName
        end

        return use
      end
    end
  else
    if data.special_skill then
      local skill = Fk.skills[data.special_skill]
      assert(skill:isInstanceOf(ActiveSkill))
      ---@cast skill ActiveSkill
      skill:onUse(self, SkillUseData:new {
        from = player,
        cards = { card },
        tos = table.map(targets, Util.Id2PlayerMapper),
      })
      return nil
    end
    local use = {}
    use.from = player
    use.tos = {}
    for _, targetId in ipairs(targets or Util.DummyTable) do
      table.insert(use.tos, self:getPlayerById(targetId))
    end
    Fk:filterCard(card, player)
    use.card = Fk:getCardById(card)
    return use
  end
end

---@class AskToUseRealCardParams
---@field pattern string|integer[] @ 选卡规则，或可选的牌id表
---@field skill_name? string @ 烧条时显示的技能名
---@field prompt? string @ 询问提示信息。默认为：请使用一张牌
---@field extra_data? UseExtraData|table @ 额外信息，因技能而异了
---@field cancelable? boolean @ 是否可以取消。默认可以取消
---@field skip? boolean @ 是否跳过使用。默认不跳过
---@field expand_pile? string|integer[] @ 可选私人牌堆名称，或额外可选牌

--- 询问玩家从一些实体牌中选一个使用。默认无次数限制，与askForUseCard主要区别是不能调用转化技
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToUseRealCardParams @ 各种变量
---@return UseCardDataSpec? @ 返回卡牌使用框架。取消使用则返回空
function Room:askToUseRealCard(player, params)
  params.pattern = type(params.pattern) == "string" and params.pattern or tostring(Exppattern{ id = params.pattern })
  params.skill_name = params.skill_name or ""
  params.prompt = params.prompt or ("#AskForUseOneCard:::"..params.skill_name)
  if (params.cancelable == nil) then params.cancelable = true end
  local extra_data = params.extra_data and table.simpleClone(params.extra_data) or {}
  if extra_data.bypass_times == nil then extra_data.bypass_times = true end
  if extra_data.extraUse == nil then extra_data.extraUse = true end
  local pattern, skillName, prompt, cancelable, skipUse = params.pattern, params.skill_name, params.prompt, params.cancelable, params.skip

  local pile = params.expand_pile or extra_data.expand_pile
  local cards = player:getCardIds("h")
  if type(pile) == "string" then
    table.insertTable(cards, player:getPile(pile))
  elseif type(pile) == "table" then
    table.insertTable(cards, pile)
  end

  local cardIds = {}
  for _, cid in ipairs(cards) do
    local card = Fk:getCardById(cid)
    if Exppattern:Parse(pattern):match(card) then
      if #card:getAvailableTargets(player, extra_data) > 0 then
        table.insert(cardIds, cid)
      end
    end
  end
  extra_data.skillName = skillName
  if #cardIds == 0 and not cancelable then return end
  extra_data.cardIds = cardIds
  local _, dat = self:askToUseViewAsSkill(player, { skill_name = "userealcard_skill", prompt = prompt, cancelable = cancelable, extra_data = extra_data })
  if (not cancelable) and (not dat) then
    for _, cid in ipairs(cardIds) do
      local card = Fk:getCardById(cid)
      local temp = card:getDefaultTarget (player, extra_data)
      if #temp > 0 then
        dat = {targets = temp, cards = {cid}}
        break
      end
    end
  end
  if not dat then return end
  local use = {
    from = player,
    tos = dat.targets,
    card = Fk:getCardById(dat.cards[1]),
    extraUse = extra_data.extraUse,
  }
  if not skipUse then
    self:useCard(use)
  end
  return use
end

---@class AskToUseCardParams
---@field skill_name? string @ 烧条时显示的技能名
---@field pattern string|integer[] @ 使用牌的规则
---@field prompt? string @ 提示信息
---@field cancelable? boolean @ 是否可以取消。默认可以取消
---@field extra_data? UseExtraData|table @ 额外信息，因技能而异了
---@field event_data? CardEffectData @ 事件信息

-- available extra_data:
-- * must_targets: integer[]
-- * exclusive_targets: integer[]
-- * fix_targets: integer[]
-- * bypass_distances: boolean
-- * bypass_times: boolean
---
--- 询问玩家使用一张牌。
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToUseCardParams @ 各种变量
---@return UseCardDataSpec? @ 返回关于本次使用牌的数据，以便后续处理
function Room:askToUseCard(player, params)
  params.cancelable = (params.cancelable == nil) and true or params.cancelable
  local extra_data = params.extra_data and table.simpleClone(params.extra_data) or {}
  if extra_data.bypass_times == nil then extra_data.bypass_times = true end
  params.prompt = params.prompt or ""
  local card_name, prompt, cancelable, event_data = params.skill_name, params.prompt, params.cancelable, params.event_data
  if event_data and (event_data.disresponsive or table.contains(event_data.disresponsiveList or Util.DummyTable, player.id)) then
    return nil
  end
  local pattern = params.pattern

  if event_data and event_data.prohibitedCardNames then
    local exp = Exppattern:Parse(pattern)
    for _, matcher in ipairs(exp.matchers) do
      matcher.name = table.filter(matcher.name, function(name)
        return not table.contains(event_data.prohibitedCardNames, name)
      end)
      if #matcher.name == 0 then return nil end
    end
    pattern = tostring(exp)
  end

  local command = "AskForUseCard"

  local askForUseCardData = {
    user = player,
    cardName = card_name,
    pattern = pattern,
    extraData = extra_data,
    eventData = event_data,
  }
  self.logic:trigger(fk.AskForCardUse, player, askForUseCardData)

  local useResult
  if askForUseCardData.result then
    if type(askForUseCardData.result) == 'table' then
      useResult = askForUseCardData.result
    else
      askForUseCardData.result = nil
    end
  else
    local disabledSkillNames = {}

    repeat
      useResult = nil
      local data = {card_name, pattern, prompt, cancelable, extra_data, disabledSkillNames}

      Fk.currentResponsePattern = pattern
      self.logic:trigger(fk.HandleAskForPlayCard, nil, askForUseCardData, true)

      local req = Request:new(player, command)
      req.focus_text = card_name or ""
      req:setData(player, data)
      local result = req:getResult(player)

      askForUseCardData.afterRequest = true
      self.logic:trigger(fk.HandleAskForPlayCard, nil, askForUseCardData, true)
      Fk.currentResponsePattern = nil

      if result ~= "" then
        useResult = self:handleUseCardReply(player, result)

        if type(useResult) == "string" and useResult ~= "" then
          table.insertIfNeed(disabledSkillNames, useResult)
        end
      end
    until type(useResult) ~= "string"

    askForUseCardData.result = useResult
  end

  self.logic:trigger(fk.AfterAskForCardUse, player, askForUseCardData)
  return useResult
end

--- 询问一名玩家打出一张牌。
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToUseCardParams @ 各种变量
---@return Card? @ 打出的牌
function Room:askToResponse(player, params)
  params.cancelable = (params.cancelable == nil) and true or params.cancelable
  local extra_data = params.extra_data and table.simpleClone(params.extra_data) or {}
  params.prompt = params.prompt or ""
  local card_name, pattern, prompt, cancelable, event_data =
    params.skill_name, params.pattern, params.prompt,
    params.cancelable, params.event_data
  if event_data and (event_data.disresponsive or table.contains(event_data.disresponsiveList or Util.DummyTable, player.id)) then
    return nil
  end

  local command = "AskForResponseCard"

  local eventData = {
    user = player,
    cardName = card_name,
    pattern = pattern,
    extraData = extra_data,
    eventData = event_data,
  }
  self.logic:trigger(fk.AskForCardResponse, player, eventData)

  local responseResult
  if eventData.result then
    if type(eventData.result) == "table" then
      responseResult = eventData.result
    else
      eventData.result = nil
    end
  else
    local disabledSkillNames = {}

    repeat
      responseResult = nil
      local data = {card_name, pattern, prompt, cancelable, extra_data, disabledSkillNames}

      Fk.currentResponsePattern = pattern
      eventData.isResponse = true
      self.logic:trigger(fk.HandleAskForPlayCard, nil, eventData, true)

      local req = Request:new(player, command)
      req.focus_text = card_name or ""
      req:setData(player, data)
      local result = req:getResult(player)

      eventData.afterRequest = true
      self.logic:trigger(fk.HandleAskForPlayCard, nil, eventData, true)
      Fk.currentResponsePattern = nil

      if result ~= "" then
        responseResult = self:handleUseCardReply(player, result)

        if type(responseResult) == "string" and responseResult ~= "" then
          table.insertIfNeed(disabledSkillNames, responseResult)
        end
      end
    until type(responseResult) ~= "string"

    if responseResult then
      responseResult = responseResult.card
    end

    eventData.result = responseResult
  end

  self.logic:trigger(fk.AfterAskForCardResponse, player, eventData)
  return responseResult
end

--- 同时询问多名玩家是否使用某一张牌。
---
--- 函数名字虽然是“询问无懈可击”，不过其实也可以给别的牌用就是了。
---@param players ServerPlayer[] @ 要询问的玩家列表
---@param params AskToUseCardParams @ 各种变量
---@return UseCardDataSpec? @ 最终决胜出的卡牌使用信息
function Room:askToNullification(players, params)
  params.cancelable = (params.cancelable == nil) and true or params.cancelable
  local extra_data = params.extra_data and table.simpleClone(params.extra_data) or {}
  params.prompt = params.prompt or ""

  local card_name, pattern, prompt, cancelable, event_data =
    params.skill_name, params.pattern, params.prompt,
    params.cancelable, params.event_data
  if #players == 0 then
    self.logic:trigger(fk.AfterAskForNullification, nil, { eventData = event_data })
    return nil
  end

  local command = "AskForUseCard"

  local useResult
  local disabledSkillNames = {}

  repeat
    useResult = nil

    local data = {card_name, pattern, prompt, cancelable, extra_data, disabledSkillNames}

    Fk.currentResponsePattern = pattern

    local eventData = {
      cardName = card_name,
      pattern = pattern,
      extraData = extra_data,
      eventData = event_data,
    }
    self.logic:trigger(fk.HandleAskForPlayCard, nil, eventData, true)

    local req = Request:new(players, command, 1)
    req.focus_players = self.alive_players
    req.focus_text = card_name
    for _, p in ipairs(players) do req:setData(p, data) end
    req:ask()
    local winner = req.winners[1]

    eventData.afterRequest = true
    self.logic:trigger(fk.HandleAskForPlayCard, nil, eventData, true)

    if winner then
      local result = req:getResult(winner)
      useResult = self:handleUseCardReply(winner, result)

      if type(useResult) == "string" and useResult ~= "" then
        table.insertIfNeed(disabledSkillNames, useResult)
      end
    end
    Fk.currentResponsePattern = nil
  until type(useResult) ~= "string"

  local askForNullificationData = {
    result = useResult,
    eventData = event_data,
  }
  self.logic:trigger(fk.AfterAskForNullification, nil, askForNullificationData)
  return useResult
end

---@class AskToAGParams
---@field id_list integer[] | Card[] @ 可选的卡牌列表
---@field cancelable? boolean @ 能否点取消
---@field skill_name? string @ 烧条时显示的技能名

-- AG(a.k.a. Amazing Grace) functions
-- Popup a box that contains many cards, then ask player to choose one

--- 询问玩家从AG中选择一张牌。
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToAGParams @ 各种变量
---@return integer @ 选择的卡牌
function Room:askToAG(player, params)
  params.id_list = Card:getIdList(params.id_list)
  local id_list, cancelable, reason = params.id_list, params.cancelable, params.skill_name
  if #id_list == 1 and not cancelable then
    return id_list[1]
  end

  local command = "AskForAG"

  local data = { id_list, cancelable, reason }
  local req = Request:new(player, command)
  req.focus_text = reason
  req:setData(player, data)
  local ret = req:getResult(player)

  if ret == "" and not cancelable then
    ret = table.random(id_list)
  end
  return ret
end

--- 给player发一条消息，在他的窗口中用一系列卡牌填充一个AG。
---@param players ServerPlayer|ServerPlayer[] @ 要通知的玩家
---@param id_list integer[] | Card[] @ 要填充的卡牌
---@param disable_ids? integer[] | Card[] @ 未使用 不能选择的牌
function Room:fillAG(players, id_list, disable_ids)
  local record = self:getTag("AGrecord") or {}
  local new = true
  if players.id ~= nil then
    --- FIXEME: 很危险的判断，AG以后肯定要大改了，先这样算了
    if #record > 0 and record[#record][2][1] == id_list[1] then
      new = false
      table.insert(record[#record][1], players.id)
    end
    players = { players }
  end
  id_list = Card:getIdList(id_list)
  -- disable_ids = Card:getIdList(disable_ids)
  if new then
    --[[ 不用关闭AG，开新AG会覆盖
    if #record > 0 then
      for _, pid in ipairs(record[#record][1]) do
        self:getPlayerById(pid):doNotify("CloseAG", "")
      end
    end
    --]]
    table.insert(record, {table.map(players, Util.IdMapper), id_list, disable_ids, {}})
  end
  self:setTag("AGrecord", record)
  for _, player in ipairs(players) do
    player:doNotify("FillAG", json.encode{ id_list, disable_ids })
  end
end

--- 告诉一些玩家，AG中的牌被taker取走了。
---@param taker ServerPlayer @ 拿走牌的玩家
---@param id integer @ 被拿走的牌
---@param notify_list? ServerPlayer[] @ 要告知的玩家，默认为全员
function Room:takeAG(taker, id, notify_list)
  self:doBroadcastNotify("TakeAG", json.encode{ taker.id, id }, notify_list)
  local record = self:getTag("AGrecord") or {}
  if #record > 0 then
    local currentRecord = record[#record]
    currentRecord[4][tostring(id)] = taker.id
    self:setTag("AGrecord", record)
  end
end

--- 关闭player那侧显示的AG。
---
--- 若不传参（即player为nil），那么关闭所有玩家的AG。
---@param player? ServerPlayer @ 要关闭AG的玩家
function Room:closeAG(player)
  local record = self:getTag("AGrecord") or {}
  if player then player:doNotify("CloseAG", "")
  else
    self:doBroadcastNotify("CloseAG", "")
  end
  if #record > 0 then
    local currentRecord = record[#record]
    if player then
      table.removeOne(currentRecord[1], player.id)
      self:setTag("AGrecord", record)
      if #currentRecord[1] > 0 then return end
    end
    table.remove(record, #record)
    self:setTag("AGrecord", record)
    if #record > 0 then
      local newRecord = record[#record]
      local players = table.map(newRecord[1], Util.Id2PlayerMapper)
      for _, p in ipairs(players) do
        p:doNotify("FillAG", json.encode{ newRecord[2], newRecord[3] })
      end
      for cid, pid in pairs(newRecord[4]) do
        self:doBroadcastNotify("TakeAG", json.encode{ pid, tonumber(cid) }, players)
      end
    end
  end
end

---@class AskToMiniGameParams
---@field skill_name string @ 烧条时显示的技能名
---@field game_type string @ 小游戏框关键词
---@field data_table table<integer, any> @ 以每个playerID为键的数据数组

-- TODO: 重构request机制，不然这个还得手动拿client_reply
---@param players ServerPlayer[] @ 需要参与这个框的角色
---@param params AskToMiniGameParams @ 各种变量
function Room:askToMiniGame(players, params)
  local command = "MiniGame"
  local game = Fk.mini_games[params.game_type]
  if #players == 0 or not game then return end

  local req = Request:new(players, command)
  req.focus_text = params.skill_name
  req.receive_decode = false -- 和customDialog同理

  for _, p in ipairs(players) do
    local data = params.data_table[p.id]
    p.mini_game_data = { type = params.game_type, data = data }
    req:setData(p, p.mini_game_data)
    req:setDefaultReply(p, game.default_choice and json.encode(game.default_choice(p, data)))
  end

  req:ask()

  for _, p in ipairs(players) do
    p.mini_game_data = nil
  end
end

---@class AskToCustomDialogParams
---@field skill_name string @ 烧条时显示的技能名
---@field qml_path string @ 小游戏框关键词
---@field extra_data any @ 额外信息，因技能而异了

-- Show a qml dialog and return qml's ClientInstance.replyToServer
-- Do anything you like through this function

-- 调用一个自定义对话框，须自备loadData方法
---@param player ServerPlayer @ 询问的角色
---@param params AskToCustomDialogParams @ 各种变量
---@return string @ 格式化字符串，可能需要json.decode
function Room:askToCustomDialog(player, params)
  local command = "CustomDialog"
  local req = Request:new(player, command)
  req.focus_text = params.skill_name
  req.receive_decode = false -- 没法知道要不要decode，所以我写false (json.decode该杀啊)
  req:setData(player, {
    path = params.qml_path,
    data = params.extra_data,
  })
  return req:getResult(player)
end

---@class AskToMoveCardInBoardParams
---@field target_one ServerPlayer @ 移动的目标1玩家
---@field target_two ServerPlayer @ 移动的目标2玩家
---@field skill_name string @ 技能名
---@field flag? "e" | "j" @ 限定可移动的区域，值为nil（装备区和判定区）、‘e’或‘j’
---@field move_from? ServerPlayer @ 移动来源是否只能是某角色
---@field exclude_ids? integer[] @ 本次不可移动的卡牌id

--- 询问移动场上的一张牌。不可取消
---@param player ServerPlayer @ 移动的操作者
---@param params AskToMoveCardInBoardParams @ 各种变量
---@return table<"card"|"from"|"to">? @ 选择的卡牌、起点玩家id和终点玩家id列表
function Room:askToMoveCardInBoard(player, params)
  params.exclude_ids = type(params.exclude_ids) == "table" and params.exclude_ids or {}

  local targetOne, targetTwo, skillName, flag, moveFrom, excludeIds =
    params.target_one, params.target_two, params.skill_name,
    params.flag, params.move_from, params.exclude_ids

  if flag then
    assert(flag == "e" or flag == "j")
  end

  local cards = {}
  local cardsPosition = {}

  if not flag or flag == "e" then
    if not moveFrom or moveFrom == targetOne then
      for _, equipId in ipairs(targetOne:getCardIds(Player.Equip)) do
        if not table.contains(excludeIds, equipId) and targetOne:canMoveCardInBoardTo(targetTwo, equipId) then
          table.insert(cards, equipId)
        end
      end
    end
    if not moveFrom or moveFrom == targetTwo then
      for _, equipId in ipairs(targetTwo:getCardIds(Player.Equip)) do
        if not table.contains(excludeIds, equipId) and targetTwo:canMoveCardInBoardTo(targetOne, equipId) then
          table.insert(cards, equipId)
        end
      end
    end

    if #cards > 0 then
      table.sort(cards, function(prev, next)
        local prevSubType = Fk:getCardById(prev).sub_type
        local nextSubType = Fk:getCardById(next).sub_type

        return prevSubType < nextSubType
      end)

      for _, id in ipairs(cards) do
        table.insert(cardsPosition, self:getCardOwner(id) == targetOne and 0 or 1)
      end
    end
  end

  if not flag or flag == "j" then
    if not moveFrom or moveFrom == targetOne then
      for _, trickId in ipairs(targetOne:getCardIds(Player.Judge)) do
        if not table.contains(excludeIds, trickId) and targetOne:canMoveCardInBoardTo(targetTwo, trickId) then
          table.insert(cards, trickId)
          table.insert(cardsPosition, 0)
        end
      end
    end
    if not moveFrom or moveFrom == targetTwo then
      for _, trickId in ipairs(targetTwo:getCardIds(Player.Judge)) do
        if not table.contains(excludeIds, trickId) and targetTwo:canMoveCardInBoardTo(targetOne, trickId) then
          table.insert(cards, trickId)
          table.insert(cardsPosition, 1)
        end
      end
    end
  end

  if #cards == 0 then
    return
  end

  local firstGeneralName = targetOne.general + (targetOne.deputyGeneral ~= "" and ("/" .. targetOne.deputyGeneral) or "")
  local secGeneralName = targetTwo.general + (targetTwo.deputyGeneral ~= "" and ("/" .. targetTwo.deputyGeneral) or "")

  local data = {
    cards = cards,
    cardsPosition = cardsPosition,
    generalNames = { firstGeneralName, secGeneralName },
    playerIds = { targetOne.id, targetTwo.id }
  }
  local command = "AskForMoveCardInBoard"
  local req = Request:new(player, command)
  req:setData(player, data)
  local result = req:getResult(player)

  if result == "" then
    local randomIndex = math.random(1, #cards)
    result = { cardId = cards[randomIndex], pos = cardsPosition[randomIndex] }
  end

  local from, to
  if result.pos == 0 then
    from, to = targetOne, targetTwo
  else
    from, to = targetTwo, targetOne
  end
  local cardToMove = self:getCardOwner(result.cardId):getVirualEquip(result.cardId) or Fk:getCardById(result.cardId)
  self:moveCardTo(
    cardToMove,
    cardToMove.type == Card.TypeEquip and Player.Equip or Player.Judge,
    to,
    fk.ReasonPut,
    skillName,
    nil,
    true,
    player.id
  )

  return { card = cardToMove, from = from.id, to = to.id }
end

---@class AskToChooseToMoveCardInBoardParams: AskToUseActiveSkillParams
---@field flag? "e" | "j" @ 限定可移动的区域，值为nil（装备区和判定区）、‘e’或‘j’
---@field exclude_ids? integer[] @ 本次不可移动的卡牌id

--- 询问一名玩家从targets中选择出若干名玩家来移动场上的牌。
---@param player ServerPlayer @ 要做选择的玩家
---@param params AskToChooseToMoveCardInBoardParams @ 各种变量
---@return integer[] @ 选择的玩家id列表，可能为空
function Room:askToChooseToMoveCardInBoard(player, params)
  if params.flag then
    assert(params.flag == "e" or params.flag == "j")
  end
  params.cancelable = (params.cancelable == nil) and true or params.cancelable
  params.no_indicate = (params.no_indicate == nil) and true or params.no_indicate
  params.exclude_ids = type(params.exclude_ids) == "table" and params.exclude_ids or {}
  params.prompt = params.prompt or ""

  if #self:canMoveCardInBoard(params.flag, nil, params.exclude_ids) == 0 and not params.cancelable then return {} end

  local data = {
    flag = params.flag,
    skillName = params.skill_name,
    excludeIds = params.exclude_ids,
  }
  local activeParams = { ---@type AskToUseActiveSkillParams
    skill_name = "choose_players_to_move_card_in_board",
    prompt = params.prompt,
    cancelable = params.cancelable,
    extra_data = data,
    no_indicate = params.no_indicate
  }
  local _, ret = self:askToUseActiveSkill(player, activeParams)

  if ret then
    return ret.targets
  else
    if params.cancelable then
      return {}
    else
      return self:canMoveCardInBoard(params.flag, params.exclude_ids)
    end
  end
end

--- 改变玩家的护甲数
---@param player ServerPlayer
---@param num integer @ 变化量
function Room:changeShield(player, num)
  if num == 0 then return end
  player.shield = math.max(player.shield + num, 0)
  player.shield = math.min(player.shield, 5)
  self:broadcastProperty(player, "shield")
end

-- 杂项函数

function Room:adjustSeats()
  self.logic:adjustSeats()
end

--- 令两名角色交换座位
---@param a ServerPlayer
---@param b ServerPlayer
function Room:swapSeat(a, b)
  local ai, bi
  local players = self.players
  for i, v in ipairs(self.players) do
    if v == a then ai = i end
    if v == b then bi = i end
  end

  players[ai] = b
  players[bi] = a

  self:arrangeSeats()
end

--- 按输入的角色表重新改变座位。若无输入，仅更新角色座位UI
---@param players? ServerPlayer[]
function Room:arrangeSeats(players)
  assert(players == nil or #players == #self.players)
  players = players or self.players
  self.players = players

  for i = 1, #players do
    players[i].seat = i
    players[i].next = players[i + 1] or players[1]
  end

  local player_circle = table.map(players, Util.IdMapper)
  self:doBroadcastNotify("ArrangeSeats", json.encode(player_circle))
end

--- 洗牌。
function Room:shuffleDrawPile()
  local seed = math.random(2 << 32 - 1)
  AbstractRoom.shuffleDrawPile(self, seed)

  self:doBroadcastNotify("ShuffleDrawPile", seed)
  self:doBroadcastNotify("UpdateDrawPile", tostring(#self.draw_pile))

  self.logic:trigger(fk.AfterDrawPileShuffle, nil, {})
end

-- 强制同步牌堆（用于在不因任何移动事件且不因洗牌导致的牌堆变动）
function Room:syncDrawPile()
  self:doBroadcastNotify("SyncDrawPile", json.encode(self.draw_pile))
  self:doBroadcastNotify("UpdateDrawPile", tostring(#self.draw_pile))
end

---@param room Room
local function shouldUpdateWinRate(room)
  if room.settings.enableFreeAssign then
    return false
  end
  if os.time() - room.start_time < 45 then
    return false
  end
  for _, p in ipairs(room.players) do
    if p.id < 0 then return false end
  end
  return Fk.game_modes[room.settings.gameMode]:countInFunc(room)
end

--- 结束一局游戏。
---@param winner string @ 获胜的身份，空字符串表示平局
function Room:gameOver(winner)
  if not self.game_started then return end
  self.room:destroyRequestTimer()

  if table.contains(
    { "running", "normal" },
    coroutine.status(self.main_co)
  ) then
    self.logic:trigger(fk.GameFinished, nil, winner)
  end

  self.game_started = false
  self.game_finished = true

  self:setBanner("GameSummary", self:getGameSummary())
  for _, p in ipairs(self.players) do
    -- self:broadcastProperty(p, "role")
    self:setPlayerProperty(p, "role_shown", true)
    for _, _p in ipairs(self.players) do -- 偷懒！
      if _p ~= p then p:addBuddy(_p) end
    end
  end
  self:doBroadcastNotify("GameOver", winner)
  fk.qInfo(string.format("[GameOver] %d, %s, %s, in %ds", self.id, self.settings.gameMode, winner, os.time() - self.start_time))

  if shouldUpdateWinRate(self) then
    for _, p in ipairs(self.players) do
      local id = p.id
      local general = p.general
      local mode = self.settings.gameMode
      local result

      if p.id > 0 then
        if table.contains(winner:split("+"), p.role) then
          result = 1
        elseif winner == "" then
          result = 3
        else
          result = 2
        end

        self.room:updatePlayerWinRate(id, mode, p.role, result)
        self.room:updateGeneralWinRate(general, mode, p.role, result)
        if p.deputyGeneral and p.deputyGeneral ~= "" then
          self.room:updateGeneralWinRate(p.deputyGeneral, mode, p.role, result)
        end
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

--- 获取一局游戏的总结，包括每个玩家的回合数、回血、伤害、受伤、击杀
---@return table<integer, integer[]> @ 玩家id到总结的映射
function Room:getGameSummary()
  local summary = {}
  for _, p in ipairs(self.players) do
    summary[p.seat] = { turn = 0, recover = 0, damage = 0, damaged = 0, kill = 0, scname = p._splayer:getScreenName()} -- 回合，回血，伤害，受伤，击杀
  end

  self.logic:getEventsOfScope(GameEvent.Turn, 1, function (e)
    if e.data.who then
      summary[e.data.who.seat].turn = summary[e.data.who.seat].turn + 1 -- 回合
    end
    return false
  end, Player.HistoryGame)
  self.logic:getEventsOfScope(GameEvent.Recover, 1, function (e)
    local recover = e.data.who
    summary[recover.seat].recover = summary[recover.seat].recover + e.data.num -- 回血
    return false
  end, Player.HistoryGame)
  self.logic:getEventsOfScope(GameEvent.Death, 1, function (e)
    local damage = e.data.damage
    if damage and damage.from then
      summary[damage.from.seat].kill = summary[damage.from.seat].kill + 1 -- 击杀
    end
    return false
  end, Player.HistoryGame)
  self.logic:getActualDamageEvents(1, function (e)
    local damage = e.data
    local from, to = damage.from, damage.to
    if from then summary[from.seat].damage = summary[from.seat].damage + damage.damage end -- 伤害
    summary[to.seat].damaged = summary[to.seat].damaged + damage.damage -- 受伤
    return false
  end, nil, 1)
  return summary
end

--- 获取可以移动场上牌的第一对目标。用于判断场上是否可以移动的牌
---@param flag? "e"|"j" @ 判断移动的区域
---@param players? ServerPlayer[] @ 可移动的玩家
---@param excludeIds? integer[] @ 不能移动的卡牌id
---@return integer[] @ 玩家id列表 可能为空表
function Room:canMoveCardInBoard(flag, players, excludeIds)
  if flag then
    assert(flag == "e" or flag == "j")
  end

  players = players or self.alive_players
  excludeIds = type(excludeIds) == "table" and excludeIds or {}

  for _, from in ipairs(players) do
    local to = table.find(players, function(p)
      return p ~= from and from:canMoveCardsInBoardTo(p, flag, excludeIds)
    end)
    if to then
      return { from.id, to.id }
    end
  end

  return {}
end

--- 现场印卡。当然了，这个卡只和这个房间有关。
---@param name string @ 牌名
---@param suit? Suit @ 花色
---@param number? integer @ 点数
---@return Card
function Room:printCard(name, suit, number)
  local cd = AbstractRoom.printCard(self, name, suit, number)
  self:doBroadcastNotify("PrintCard", json.encode{ name, suit, number })
  return cd
end

--- 刷新使命技状态
---@param player ServerPlayer
---@param skillName string
---@param failed? boolean
function Room:updateQuestSkillState(player, skillName, failed)
  assert(Fk.skills[skillName].frequency == Skill.Quest)

  self:setPlayerMark(player, MarkEnum.QuestSkillPreName .. skillName, failed and "failed" or "succeed")
  local updateValue = failed and 2 or 1

  self:doBroadcastNotify("UpdateQuestSkillUI", json.encode{
    player.id,
    skillName,
    updateValue,
  })
end

--- 废除区域
---@param player ServerPlayer
---@param playerSlots string | string[]
function Room:abortPlayerArea(player, playerSlots)
  assert(type(playerSlots) == "string" or type(playerSlots) == "table")

  if type(playerSlots) == "string" then
    playerSlots = { playerSlots }
  end

  local cardsToDrop = {}
  local slotsSealed = {}
  local slotsToSeal = {}
  for _, slot in ipairs(playerSlots) do
    if slot == Player.JudgeSlot then
      if not table.contains(player.sealedSlots, Player.JudgeSlot) then
        table.insertIfNeed(slotsToSeal, slot)

        local delayedTricks = player:getCardIds(Player.Judge)
        if #delayedTricks > 0 then
          table.insertTable(cardsToDrop, delayedTricks)
        end
      end
    else
      local subtype = Util.convertSubtypeAndEquipSlot(slot)
      if #player:getAvailableEquipSlots(subtype) > 0 then
        table.insert(slotsToSeal, slot)

        local equipmentIndex = (slotsSealed[tostring(subtype)] or 0) + 1
        slotsSealed[tostring(subtype)] = equipmentIndex

        if equipmentIndex <= #player:getEquipments(subtype) then
          table.insert(cardsToDrop, player:getEquipments(subtype)[equipmentIndex])
        end
      end
    end
  end

  if #slotsToSeal == 0 then
    return
  end

  self:moveCards({
    ids = cardsToDrop,
    from = player,
    toArea = Card.DiscardPile,
    moveReason = fk.ReasonPutIntoDiscardPile,
    skillName = "gamerule_aborted"
  })

  table.insertTable(player.sealedSlots, slotsToSeal)
  self:broadcastProperty(player, "sealedSlots")

  for _, s in ipairs(slotsToSeal) do
    self:sendLog{
      type = "#AbortArea",
      from = player.id,
      arg = s,
    }
  end
  self.logic:trigger(fk.AreaAborted, player, { slots = slotsSealed })
end

--- 恢复区域
---@param player ServerPlayer
---@param playerSlots string | string[]
function Room:resumePlayerArea(player, playerSlots)
  assert(type(playerSlots) == "string" or type(playerSlots) == "table")

  if type(playerSlots) == "string" then
    playerSlots = { playerSlots }
  end

  local slotsToResume = {}
  for _, slot in ipairs(playerSlots) do
    for i = 1, #player.sealedSlots do
      if player.sealedSlots[i] == slot then
        table.remove(player.sealedSlots, i)
        table.insert(slotsToResume, slot)
      end
    end
  end

  if #slotsToResume > 0 then
    self:broadcastProperty(player, "sealedSlots")
    for _, s in ipairs(slotsToResume) do
      self:sendLog{
        type = "#ResumeArea",
        from = player.id,
        arg = s,
      }
    end
    self.logic:trigger(fk.AreaResumed, player, { slots = slotsToResume })
  end
end

---@param player ServerPlayer
---@param playerSlots string | string[]
function Room:addPlayerEquipSlots(player, playerSlots)
  assert(type(playerSlots) == "string" or type(playerSlots) == "table")

  if type(playerSlots) == "string" then
    playerSlots = { playerSlots }
  end

  for _, slot in ipairs(playerSlots) do
    local slotIndex = table.indexOf(player.equipSlots, slot)
    if slotIndex > -1 then
      table.insert(player.equipSlots, slotIndex, slot)
    else
      table.insert(player.equipSlots, slot)
    end
    self:sendLog{
      type = "#AddNewArea",
      from = player.id,
      arg = slot,
    }
  end

  self:broadcastProperty(player, "equipSlots")
end

---@param player ServerPlayer
---@param playerSlots string | string[]
function Room:removePlayerEquipSlots(player, playerSlots)
  assert(type(playerSlots) == "string" or type(playerSlots) == "table")

  if type(playerSlots) == "string" then
    playerSlots = { playerSlots }
  end

  for _, slot in ipairs(playerSlots) do
    table.removeOne(player.equipSlots, slot)
  end

  self:broadcastProperty(player, "equipSlots")
end

---@param player ServerPlayer
---@param playerSlots string[]
function Room:setPlayerEquipSlots(player, playerSlots)
  assert(type(playerSlots) == "table")
  player.equipSlots = playerSlots

  self:broadcastProperty(player, "equipSlots")
end

--- 设置休整
---@param player ServerPlayer
---@param roundNum integer
function Room:setPlayerRest(player, roundNum)
  player.rest = roundNum
  self:broadcastProperty(player, "rest")
end

--- 结束当前回合（不会终止结算）
function Room:endTurn()
  self.current._phase_end = true
  self:setTag("endTurn", true)
end

--清理遗留在处理区的卡牌
---@param cards? integer[] @ 待清理的卡牌。不填则清理处理区所有牌
---@param skillName? string @ 技能名
function Room:cleanProcessingArea(cards, skillName)
  local throw = cards and table.filter(cards, function(id) return self:getCardArea(id) == Card.Processing end) or self.processing_area
  if #throw > 0 then
    self:moveCardTo(throw, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile, skillName)
  end
end

--- 为角色或牌的表型标记添加值
---@param sth ServerPlayer|Card @ 更新标记的玩家或卡牌
---@param mark string @ 标记的名称
---@param value any @ 要增加的值
function Room:addTableMark(sth, mark, value)
  local t = sth:getTableMark(mark)
  table.insert(t, value)
  if sth:isInstanceOf(Card) then
    self:setCardMark(sth, mark, t)
  else
    self:setPlayerMark(sth, mark, t)
  end
end

--- 为角色或牌的表型标记添加值，若已存在则不添加
---@param sth ServerPlayer|Card @ 更新标记的玩家或卡牌
---@param mark string @ 标记的名称
---@param value any @ 要增加的值
---@return boolean @ 是否添加成功
function Room:addTableMarkIfNeed(sth, mark, value)
  local t = sth:getTableMark(mark)
  if not table.insertIfNeed(t, value) then return false end
  if sth:isInstanceOf(Card) then
    self:setCardMark(sth, mark, t)
  else
    self:setPlayerMark(sth, mark, t)
  end
  return true
end

--- 为角色或牌的表型标记移除值，移为空表后重置标记值为0
---@param sth ServerPlayer|Card @ 更新标记的玩家或卡牌
---@param mark string @ 标记的名称
---@param value any @ 要移除的值
---@return boolean @ 是否移除成功(若标记中未含此值则移除失败)
function Room:removeTableMark(sth, mark, value)
  local t = sth:getTableMark(mark)
  if not table.removeOne(t, value) then return false end
  if sth:isInstanceOf(Card) then
    self:setCardMark(sth, mark, #t > 0 and t or 0)
  else
    self:setPlayerMark(sth, mark, #t > 0 and t or 0)
  end
  return true
end

--- 无效化技能
---@param player ServerPlayer
---@param skill_name string
---@param temp? string @ 作用范围，``-round`` ``-turn`` ``-phase``或不填
function Room:invalidateSkill(player, skill_name, temp)
  temp = temp and temp or ""
  self:addTableMark(player, MarkEnum.InvalidSkills .. temp, skill_name)
end

--- 有效化技能
---@param player ServerPlayer
---@param skill_name string
---@param temp? string @ 作用范围，``-round`` ``-turn`` ``-phase``或不填
function Room:validateSkill(player, skill_name, temp)
  temp = temp and temp or ""
  self:removeTableMark(player, MarkEnum.InvalidSkills .. temp, skill_name)
end


--- 将触发技或状态技添加到房间
---@param skill Skill|string
function Room:addSkill(skill)
  if type(skill) == "string" then
    skill = Fk.skills[skill]
  end
  if skill == nil then return end
  if skill:isInstanceOf(StatusSkill) then
    self.status_skills[skill.class] = self.status_skills[skill.class] or {}
    table.insertIfNeed(self.status_skills[skill.class], skill)
    -- add status_skill to cilent room
    self:doBroadcastNotify("AddStatusSkill", json.encode{ skill.name })
  elseif skill:isInstanceOf(TriggerSkill) then
    self.logic:addTriggerSkill(skill)
  end
end


return Room
