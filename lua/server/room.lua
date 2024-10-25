-- SPDX-License-Identifier: GPL-3.0-or-later

--- Room是fk游戏逻辑运行的主要场所，同时也提供了许多API函数供编写技能使用。
---
--- 一个房间中只有一个Room实例，保存在RoomInstance全局变量中。
---@class Room : AbstractRoom, GameEventWrappers
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
local Room = AbstractRoom:subclass("Room")

-- load classes used by the game
Request = require "server.network"
GameEvent = require "server.gameevent"
local GameEventWrappers = require "lua/server/events"
Room:include(GameEventWrappers)
GameLogic = require "server.gamelogic"
ServerPlayer = require "server.serverplayer"

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

-- 因为现在已经不是轮询了，加上有点难分析
-- 选择开摆
function Room:isReady()
  -- 因为delay函数而延时：判断延时是否已经结束。
  -- 注意整个delay函数的实现都搬到这来了，delay本身只负责挂起协程了。
  --[[
  if self.in_delay then
    local rest = self.delay_duration - (os.getms() - self.delay_start) / 1000
    if rest <= 50 then
      self.in_delay = false
      return true
    end
    return false, rest
  end
  --]]
  return true
end

--[[
-- 供调度器使用的函数，用来指示房间是否就绪。
-- 如果没有就绪的话，可能会返回第二个值来告诉调度器自己还有多久就绪。
function Room:isReady()
  -- 没有活人了？那就告诉调度器我就绪了，恢复时候就会自己杀掉
  if self:checkNoHuman(true) then
    return true
  end

  -- 剩下的就是因为等待应答而未就绪了
  -- 检查所有正在等回答的玩家，如果已经过了烧条时间
  -- 那么就不认为他还需要时间就绪了
  -- 然后在调度器第二轮刷新的时候就应该能返回自己已就绪
  local ret = true
  local rest
  for _, p in ipairs(self.players) do
    -- 这里判断的话需要用_splayer了，不然一控多的情况下会导致重复判断
    if p._splayer:thinking() then
      -- 烧条烧光了的话就把thinking设为false
      rest = p.request_timeout * 1000 - (os.getms() -
        p.request_start) / 1000

      if rest <= 0 or p.serverplayer:getState() ~= fk.Player_Online then
        p._splayer:setThinking(false)
      else
        ret = false
      end
    end

    if self.race_request_list and table.contains(self.race_request_list, p) then
      local result = p.serverplayer:waitForReply(0)
      if result ~= "__notready" and result ~= "__cancel" and result ~= "" then
        return true
      end
    end
  end
  return ret, (rest and rest > 1) and rest or nil
end
--]]

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

--[[ 敢删就寄，算了
function Room:__gc()
  self.room:checkAbandoned()
end
--]]

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

--- 根据玩家id，获得那名玩家本人。
---@param id integer @ 玩家的id
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

--- 将房间中的玩家按照行动顺序重新排序。
---@param playerIds integer[] @ 玩家id列表，这个数组会被这个函数排序
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

function Room:deadPlayerFilter(playerIds)
  local newPlayerIds = {}
  for _, playerId in ipairs(playerIds) do
    if self:getPlayerById(playerId):isAlive() then
      table.insert(newPlayerIds, playerId)
    end
  end

  return newPlayerIds
end

--- 获得当前房间中的所有玩家。
---
--- 返回的数组的第一个元素是当前回合玩家，并且按行动顺序进行排序。
---@param sortBySeat? boolean @ 是否按座位排序，默认是
---@return ServerPlayer[] @ 房间中玩家的数组
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

--- 获得所有存活玩家，参看getAllPlayers
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

--- 获得除一名玩家外的其他玩家。
---@param player ServerPlayer @ 要排除的玩家
---@param sortBySeat? boolean @ 是否按座位排序，默认是
---@param include_dead? boolean @ 是否要把死人也算进去？
---@return ServerPlayer[] @ 其他玩家列表
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
--- 注意了，这个函数会对牌堆进行实际操作，也就是说它返回一系列id后，牌堆中就会少这么多id。
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
  local cardIds = {}
  for index = i, j, 1 do
    table.insert(cardIds, table.remove(self.draw_pile, i))
  end

  self:doBroadcastNotify("UpdateDrawPile", #self.draw_pile)

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

---@param player ServerPlayer
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

---@param player ServerPlayer
---@param general string
---@param deputy string
---@param broadcast boolean|nil
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
  o.round_count = self:getTag("RoundCount") or 0
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
function Room:doRequest(player, command, jsonData, wait)
  -- fk.qCritical("Room:doRequest is deprecated!")
  if wait == true then error("wait can't be true") end
  local request = Request:new(command, {player})
  request.send_json = false -- 因为参数已经json.encode过了，该死的兼容性
  request.receive_json = false
  request.accept_cancel = true
  request:setData(player, jsonData)
  request:ask()
  return request.result[player.id]
end

--- 向多名玩家发出请求。
---@param command string @ 请求类型
---@param players? ServerPlayer[] @ 发出请求的玩家列表
---@param jsonData? string @ 请求数据
function Room:doBroadcastRequest(command, players, jsonData)
  -- fk.qCritical("Room:doBroadcastRequest is deprecated!")
  players = players or self.players
  local request = Request:new(command, players)
  request.send_json = false -- 因为参数已经json.encode过了
  request.receive_json = false
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
function Room:doRaceRequest(command, players, jsonData)
  -- fk.qCritical("Room:doRaceRequest is deprecated!")
  players = players or self.players
  local request = Request:new(command, players, 1)
  request.send_json = false -- 因为参数已经json.encode过了
  request.receive_json = false
  for _, p in ipairs(players) do
    request:setData(p, jsonData or p.request_data)
  end
  request:ask()
  return request:getWinners()[1]
end

--- 延迟一段时间。
---@param ms integer @ 要延迟的毫秒数
function Room:delay(ms)
  local start = os.getms()
  self.delay_start = start
  self.delay_duration = ms
  self.in_delay = true
  self.room:delay(math.ceil(ms))
  coroutine.yield("__handleRequest", ms)
end

--- 向多名玩家告知一次移牌行为。
---@param players? ServerPlayer[] @ 要被告知的玩家列表，默认为全员
---@param card_moves CardsMoveStruct[] @ 要告知的移牌信息列表
---@param forceVisible? boolean @ 是否让所有牌对告知目标可见
function Room:notifyMoveCards(players, card_moves, forceVisible)
  if players == nil or players == {} then players = self.players end
  for _, p in ipairs(players) do
    local arg = table.clone(card_moves)
    for _, move in ipairs(arg) do
      -- local to = self:getPlayerById(move.to)

      for _, info in ipairs(move.moveInfo) do
        local realFromArea = self:getCardArea(info.cardId)
        local playerAreas = { Player.Hand, Player.Equip, Player.Judge, Player.Special }
        local virtualEquip

        if table.contains(playerAreas, realFromArea) and move.from then
          virtualEquip = self:getPlayerById(move.from):getVirualEquip(info.cardId)
        end

        if table.contains(playerAreas, move.toArea) and move.to and virtualEquip then
          self:getPlayerById(move.to):addVirtualEquip(virtualEquip)
        end
      end

    end
    p:doNotify("MoveCards", json.encode(arg))
  end
end

--- 将焦点转移给一名或者多名角色，并广而告之。
---
--- 形象点说，就是在那些玩家下面显示一个“弃牌 思考中...”之类的烧条提示。
---@param players ServerPlayer | ServerPlayer[] @ 要获得焦点的一名或者多名角色
---@param command string @ 烧条的提示文字
function Room:notifyMoveFocus(players, command)
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
    command
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

--- 询问player是否要发动一个主动技。
---
--- 如果发动的话，那么会执行一下技能的onUse函数，然后返回选择的牌和目标等。
---@param player ServerPlayer @ 询问目标
---@param skill_name string @ 主动技的技能名
---@param prompt? string @ 烧条上面显示的提示文本内容
---@param cancelable? boolean @ 是否可以点取消
---@param extra_data? table @ 额外信息，因技能而异了
---@param no_indicate? boolean @ 是否不显示指示线
---@return boolean, table?
function Room:askForUseActiveSkill(player, skill_name, prompt, cancelable, extra_data, no_indicate)
  prompt = prompt or ""
  cancelable = (cancelable == nil) and true or cancelable
  no_indicate = (no_indicate == nil) and true or no_indicate
  extra_data = extra_data or Util.DummyTable
  local skill = Fk.skills[skill_name]
  if not (skill and (skill:isInstanceOf(ActiveSkill) or skill:isInstanceOf(ViewAsSkill))) then
    print("Attempt ask for use non-active skill: " .. skill_name)
    return false
  end

  local command = "AskForUseActiveSkill"
  self:notifyMoveFocus(player, extra_data.skillName or skill_name)  -- for display skill name instead of command name
  local data = {skill_name, prompt, cancelable, extra_data}

  Fk.currentResponseReason = extra_data.skillName
  local result = self:doRequest(player, command, json.encode(data))
  Fk.currentResponseReason = nil

  if result == "" then
    return false
  end

  data = json.decode(result)
  local card = data.card
  local targets = data.targets
  local card_data = json.decode(card)
  local selected_cards = card_data.subcards
  local interaction
  if not no_indicate then
    self:doIndicate(player.id, targets)
  end

  if skill.interaction then
    interaction = data.interaction_data
    skill.interaction.data = interaction
  end

  if skill:isInstanceOf(ActiveSkill) then
    skill:onUse(self, {
      from = player.id,
      cards = selected_cards,
      tos = targets,
    })
  end

  return true, {
    cards = selected_cards,
    targets = targets,
    interaction = interaction
  }
end

Room.askForUseViewAsSkill = Room.askForUseActiveSkill

--- 询问一名角色弃牌。
---
--- 在这个函数里面牌已经被弃掉了（除非skipDiscard为true）。
---@param player ServerPlayer @ 弃牌角色
---@param minNum integer @ 最小值
---@param maxNum integer @ 最大值
---@param includeEquip? boolean @ 能不能弃装备区？
---@param skillName? string @ 引发弃牌的技能名
---@param cancelable? boolean @ 能不能点取消？
---@param pattern? string @ 弃牌需要符合的规则
---@param prompt? string @ 提示信息
---@param skipDiscard? boolean @ 是否跳过弃牌（即只询问选择可以弃置的牌）
---@param no_indicate? boolean @ 是否不显示指示线
---@return integer[] @ 弃掉的牌的id列表，可能是空的
function Room:askForDiscard(player, minNum, maxNum, includeEquip, skillName, cancelable, pattern, prompt, skipDiscard, no_indicate)
  cancelable = (cancelable == nil) and true or cancelable
  no_indicate = no_indicate or false
  pattern = pattern or "."

  local canDiscards = table.filter(
    player:getCardIds{ Player.Hand, includeEquip and Player.Equip or nil }, function(id)
      local checkpoint = true
      local card = Fk:getCardById(id)

      local status_skills = Fk:currentRoom().status_skills[ProhibitSkill] or Util.DummyTable
      for _, skill in ipairs(status_skills) do
        if skill:prohibitDiscard(player, card) then
          return false
        end
      end
      if skillName == "game_rule" then
        status_skills = Fk:currentRoom().status_skills[MaxCardsSkill] or Util.DummyTable
        for _, skill in ipairs(status_skills) do
          if skill:excludeFrom(player, card) then
            return false
          end
        end
      end

      if pattern ~= "" then
        checkpoint = checkpoint and (Exppattern:Parse(pattern):match(card))
      end
      return checkpoint
    end
  )

  -- maxNum = math.min(#canDiscards, maxNum)
  -- minNum = math.min(#canDiscards, minNum)

  if minNum >= #canDiscards and not cancelable then
    if not skipDiscard then
      self:throwCard(canDiscards, skillName, player, player)
    end
    return canDiscards
  end

  local toDiscard = {}
  local data = {
    num = maxNum,
    min_num = minNum,
    include_equip = includeEquip,
    skillName = skillName,
    pattern = pattern,
  }
  local prompt = prompt or ("#AskForDiscard:::" .. maxNum .. ":" .. minNum)
  local _, ret = self:askForUseActiveSkill(player, "discard_skill", prompt, cancelable, data, no_indicate)

  if ret then
    toDiscard = ret.cards
  else
    if cancelable then return {} end
    toDiscard = table.random(canDiscards, minNum) ---@type integer[]
  end

  if not skipDiscard then
    self:throwCard(toDiscard, skillName, player, player)
  end

  return toDiscard
end

--- 询问一名玩家从targets中选择若干名玩家出来。
---@param player ServerPlayer @ 要做选择的玩家
---@param targets integer[] @ 可以选的目标范围，是玩家id数组
---@param minNum integer @ 最小值
---@param maxNum integer @ 最大值
---@param prompt? string @ 提示信息
---@param skillName? string @ 技能名
---@param cancelable? boolean @ 能否点取消
---@param no_indicate? boolean @ 是否不显示指示线
---@param targetTipName? string @ 引用的选择目标提示的函数名
---@return integer[] @ 选择的玩家id列表，可能为空
function Room:askForChoosePlayers(player, targets, minNum, maxNum, prompt, skillName, cancelable, no_indicate, targetTipName)
  if maxNum < 1 then
    return {}
  end
  cancelable = (cancelable == nil) and true or cancelable
  no_indicate = no_indicate or false

  local data = {
    targets = targets,
    num = maxNum,
    min_num = minNum,
    pattern = "",
    skillName = skillName,
    targetTipName = targetTipName,
  }
  local _, ret = self:askForUseActiveSkill(player, "choose_players_skill", prompt or "", cancelable, data, no_indicate)
  if ret then
    return ret.targets
  else
    if cancelable then
      return {}
    else
      return table.random(targets, minNum)
    end
  end
end

--- 询问一名玩家选择自己的几张牌。
---
--- 与askForDiscard类似，但是不对选择的牌进行操作就是了。
---@param player ServerPlayer @ 要询问的玩家
---@param minNum integer @ 最小值
---@param maxNum integer @ 最大值
---@param includeEquip? boolean @ 能不能选装备
---@param skillName? string @ 技能名
---@param cancelable? boolean @ 能否点取消
---@param pattern? string @ 选牌规则
---@param prompt? string @ 提示信息
---@param expand_pile? string @ 可选私人牌堆名称
---@param no_indicate? boolean @ 是否不显示指示线
---@return integer[] @ 选择的牌的id列表，可能是空的
function Room:askForCard(player, minNum, maxNum, includeEquip, skillName, cancelable, pattern, prompt, expand_pile, no_indicate)
  if maxNum < 1 then
    return {}
  end
  cancelable = (cancelable == nil) and true or cancelable
  no_indicate = no_indicate or false
  pattern = pattern or "."

  local chosenCards = {}
  local data = {
    num = maxNum,
    min_num = minNum,
    include_equip = includeEquip,
    skillName = skillName,
    pattern = pattern,
    expand_pile = expand_pile,
  }
  prompt = prompt or ("#AskForCard:::" .. maxNum .. ":" .. minNum)
  local _, ret = self:askForUseActiveSkill(player, "choose_cards_skill", prompt, cancelable, data, no_indicate)
  if ret then
    chosenCards = ret.cards
  else
    if cancelable then return {} end
    local cards = player:getCardIds("he&")
    if type(expand_pile) == "string" then
      table.insertTable(cards, player:getPile(expand_pile))
    elseif type(expand_pile) == "table" then
      table.insertTable(cards, expand_pile)
    end
    local exp = Exppattern:Parse(pattern)
    cards = table.filter(cards, function(cid)
      return exp:match(Fk:getCardById(cid))
    end)
    chosenCards = table.random(cards, minNum)
  end

  return chosenCards
end

--- 询问玩家选择1张牌和若干名角色。
---
--- 返回两个值，第一个是选择的目标列表，第二个是选择的那张牌的id
---@param player ServerPlayer @ 要询问的玩家
---@param targets integer[] @ 选择目标的id范围
---@param minNum integer @ 选目标最小值
---@param maxNum integer @ 选目标最大值
---@param pattern? string @ 选牌规则
---@param prompt? string @ 提示信息
---@param cancelable? boolean @ 能否点取消
---@param no_indicate? boolean @ 是否不显示指示线
---@param targetTipName? string @ 引用的选择目标提示的函数名
---@return integer[], integer
function Room:askForChooseCardAndPlayers(player, targets, minNum, maxNum, pattern, prompt, skillName, cancelable, no_indicate, targetTipName)
  if maxNum < 1 then
    return {}
  end
  cancelable = (cancelable == nil) and true or cancelable
  no_indicate = no_indicate or false
  pattern = pattern or "."

  local pcards = table.filter(player:getCardIds({ Player.Hand, Player.Equip }), function(id)
    local c = Fk:getCardById(id)
    return c:matchPattern(pattern)
  end)
  if #pcards == 0 and not cancelable then return {} end

  local data = {
    targets = targets,
    num = maxNum,
    min_num = minNum,
    pattern = pattern,
    skillName = skillName,
    targetTipName = targetTipName,
  }
  local _, ret = self:askForUseActiveSkill(player, "choose_players_skill", prompt or "", cancelable, data, no_indicate)
  if ret then
    return ret.targets, ret.cards[1]
  else
    if cancelable then
      return {}
    else
      return table.random(targets, minNum), table.random(pcards)
    end
  end
end

--- 询问玩家选择X张牌和Y名角色。
---
--- 返回两个值，第一个是选择的目标列表，第二个是选择的牌id列表
---@param player ServerPlayer @ 要询问的玩家
---@param minCardNum integer @ 选卡牌最小值
---@param maxCardNum integer @ 选卡牌最大值
---@param targets integer[] @ 选择目标的id范围
---@param minTargetNum integer @ 选目标最小值
---@param maxTargetNum integer @ 选目标最大值
---@param pattern? string @ 选牌规则
---@param prompt? string @ 提示信息
---@param cancelable? boolean @ 能否点取消
---@param no_indicate? boolean @ 是否不显示指示线
---@return integer[], integer[]
function Room:askForChooseCardsAndPlayers(player, minCardNum, maxCardNum, targets, minTargetNum, maxTargetNum, pattern, prompt, skillName, cancelable, no_indicate, targetTipName)
  cancelable = (cancelable == nil) and true or cancelable
  no_indicate = no_indicate or false
  pattern = pattern or "."

  local pcards = table.filter(player:getCardIds({ Player.Hand, Player.Equip }), function(id)
    local c = Fk:getCardById(id)
    return c:matchPattern(pattern)
  end)
  if #pcards < minCardNum and not cancelable then return {}, {} end

  local data = {
    targets = targets,
    max_t_num = maxTargetNum,
    min_t_num = minTargetNum,
    max_c_num = maxCardNum,
    min_c_num = minCardNum,
    pattern = pattern,
    skillName = skillName,
    targetTipName = targetTipName,
  }
  local _, ret = self:askForUseActiveSkill(player, "ex__choose_skill", prompt or "", cancelable, data, no_indicate)
  if ret then
    return ret.targets, ret.cards
  else
    if cancelable then
      return {}, {}
    else
      return table.random(targets, minTargetNum), table.random(pcards, minCardNum)
    end
  end
end

--- 询问将卡牌分配给任意角色。
---@param player ServerPlayer @ 要询问的玩家
---@param cards? integer[] @ 要分配的卡牌。默认拥有的所有牌
---@param targets? ServerPlayer[] @ 可以获得卡牌的角色。默认所有存活角色
---@param skillName? string @ 技能名，影响焦点信息。默认为“分配”
---@param minNum? integer @ 最少交出的卡牌数，默认0
---@param maxNum? integer @ 最多交出的卡牌数，默认所有牌
---@param prompt? string @ 询问提示信息
---@param expand_pile? string @ 可选私人牌堆名称，如要分配你武将牌上的牌请填写
---@param skipMove? boolean @ 是否跳过移动。默认不跳过
---@param single_max? integer|table @ 限制每人能获得的最大牌数。输入整数或(以角色id为键以整数为值)的表
---@return table<integer, integer[]> @ 返回一个表，键为角色id转字符串，值为分配给其的牌id数组
function Room:askForYiji(player, cards, targets, skillName, minNum, maxNum, prompt, expand_pile, skipMove, single_max)
  targets = targets or self.alive_players
  cards = cards or player:getCardIds("he")
  local _cards = table.simpleClone(cards)
  targets = table.map(targets, Util.IdMapper)
  self:sortPlayersByAction(targets)
  skillName = skillName or "distribution_select_skill"
  minNum = minNum or 0
  maxNum = maxNum or #cards
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
  local data = {
    cards = _cards,
    max_num = maxNum,
    targets = targets,
    residued_list = residueMap,
    expand_pile = expand_pile
  }
  -- p(json.encode(residueMap))

  while maxNum > 0 and #_cards > 0 do
    data.max_num = maxNum
    prompt = prompt or ("#AskForDistribution:::"..minNum..":"..maxNum)
    local success, dat = self:askForUseActiveSkill(player, "distribution_select_skill", prompt, minNum == 0, data, true)
    if success and dat then
      local to = dat.targets[1]
      local give_cards = dat.cards
      for _, id in ipairs(give_cards) do
        table.insert(list[to], id)
        table.removeOne(_cards, id)
        self:setCardMark(Fk:getCardById(id), "@DistributionTo", Fk:translate(self:getPlayerById(to).general))
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
  if not skipMove then
    self:doYiji(list, player.id, skillName)
  end

  return list
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
---@param name string @ 武将name，如找不到则查找truename，再找不到则返回nil
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

--- 询问玩家选择一名武将。
---@param player ServerPlayer @ 询问目标
---@param generals string[] @ 可选武将
---@param n integer @ 可选数量，默认为1
---@param noConvert? boolean @ 可否变更，默认可
---@return string|string[] @ 选择的武将
function Room:askForGeneral(player, generals, n, noConvert)
  local command = "AskForGeneral"
  self:notifyMoveFocus(player, command)

  n = n or 1
  if #generals == n then return n == 1 and generals[1] or generals end
  local defaultChoice = table.random(generals, n)

  if (player.serverplayer:getState() == fk.Player_Online) then
    local result = self:doRequest(player, command, json.encode{ generals, n, noConvert })
    local choices
    if result == "" then
      choices = defaultChoice
    else
      choices = json.decode(result)
    end
    if #choices == 1 then return choices[1] end
    return choices
  end

  return n == 1 and defaultChoice[1] or defaultChoice
end

--- 询问玩家若为神将、双势力需选择一个势力。
---@param players? ServerPlayer[] @ 询问目标
function Room:askForChooseKingdom(players)
  players = players or self.alive_players
  local specialKingdomPlayers = table.filter(players, function(p)
    return Fk.generals[p.general].subkingdom or #Fk:getKingdomMap(p.kingdom) > 0
  end)

  if #specialKingdomPlayers > 0 then
    local choiceMap = {}
    for _, p in ipairs(specialKingdomPlayers) do
      local allKingdoms = {}
      local curGeneral = Fk.generals[p.general]
      if curGeneral.subkingdom then
        allKingdoms = { curGeneral.kingdom, curGeneral.subkingdom }
      else
        allKingdoms = Fk:getKingdomMap(p.kingdom)
      end
      if #allKingdoms > 0 then
        choiceMap[p.id] = allKingdoms

        local data = json.encode({ allKingdoms, allKingdoms, "AskForKingdom", "#ChooseInitialKingdom" })
        p.request_data = data
      end
    end

    self:notifyMoveFocus(players, "AskForKingdom")
    self:doBroadcastRequest("AskForChoice", specialKingdomPlayers)

    for _, p in ipairs(specialKingdomPlayers) do
      local kingdomChosen
      if p.reply_ready then
        kingdomChosen = p.client_reply
      else
        kingdomChosen = choiceMap[p.id][1]
      end

      p.kingdom = kingdomChosen
      self:notifyProperty(p, p, "kingdom")
    end
  end
end

--- 询问chooser，选择target的一张牌。
---@param chooser ServerPlayer @ 要被询问的人
---@param target ServerPlayer @ 被选牌的人
---@param flag any @ 用"hej"三个字母的组合表示能选择哪些区域, h 手牌区, e - 装备区, j - 判定区
---@param reason string @ 原因，一般是技能名
---@param prompt? string @ 提示信息
---@return integer @ 选择的卡牌id
function Room:askForCardChosen(chooser, target, flag, reason, prompt)
  local command = "AskForCardChosen"
  prompt = prompt or ""
  self:notifyMoveFocus(chooser, command)
  local data = {target.id, flag, reason, prompt}
  local result = self:doRequest(chooser, command, json.encode(data))

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
  else
    result = tonumber(result)
  end

  if result == -1 then
    local handcards = target:getCardIds(Player.Hand)
    if #handcards == 0 then return end
    result = table.random(handcards)
  end

  return result
end

--- 谋askForCardsChosen，需使用Fk:addPoxiMethod定义好方法
---
--- 选卡规则和返回值啥的全部自己想办法解决，data填入所有卡的列表（类似ui.card_data）
---
--- 注意一定要返回一个表，毕竟本质上是选卡函数
---@param player ServerPlayer
---@param poxi_type string
---@param data any
---@param extra_data any
---@param cancelable? boolean
---@return integer[]
function Room:askForPoxi(player, poxi_type, data, extra_data, cancelable)
  local poxi = Fk.poxi_methods[poxi_type]
  if not poxi then return {} end

  local command = "AskForPoxi"
  self:notifyMoveFocus(player, poxi_type)
  local result = self:doRequest(player, command, json.encode {
    type = poxi_type,
    data = data,
    extra_data = extra_data,
    cancelable = (cancelable == nil) and true or cancelable
  })

  if result == "" then
    return poxi.default_choice(data, extra_data)
  else
    return poxi.post_select(json.decode(result), data, extra_data)
  end
end

--- 完全类似askForCardChosen，但是可以选择多张牌。
--- 相应的，返回的是id的数组而不是单个id。
---@param chooser ServerPlayer @ 要被询问的人
---@param target ServerPlayer @ 被选牌的人
---@param min integer @ 最小选牌数
---@param max integer @ 最大选牌数
---@param flag any @ 用"hej"三个字母的组合表示能选择哪些区域, h 手牌区, e - 装备区, j - 判定区
---可以通过flag.card_data = {{牌堆1名, 牌堆1ID表},...}来定制能选择的牌
---@param reason string @ 原因，一般是技能名
---@param prompt? string @ 提示信息
---@return integer[] @ 选择的id
function Room:askForCardsChosen(chooser, target, min, max, flag, reason, prompt)
  if min == 1 and max == 1 then
    return { self:askForCardChosen(chooser, target, flag, reason) }
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
  local cards_data = {}
  if type(flag) == "string" then
    local handcards = target:getCardIds(Player.Hand)
    local equips = target:getCardIds(Player.Equip)
    local judges = target:getCardIds(Player.Judge)
    if string.find(flag, "h") and #handcards > 0 then
      -- TODO: 关于明置的牌
      if target ~= chooser then
        handcards = table.map(handcards, function() return -1 end)
      end
      table.insert(cards_data, {"$Hand", handcards})
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
  local ret = self:askForPoxi(chooser, "AskForCardsChosen", cards_data, data, false)
  local new_ret = table.filter(ret, function(id) return id ~= -1 end)
  local hidden_num = #ret - #new_ret
  if hidden_num > 0 then
    table.insertTable(new_ret,
    table.random(target:getCardIds(Player.Hand), hidden_num))
  end
  return new_ret
end

--- 询问一名玩家从众多选项中选择一个。
---@param player ServerPlayer @ 要询问的玩家
---@param choices string[] @ 可选选项列表
---@param skill_name? string @ 技能名
---@param prompt? string @ 提示信息
---@param detailed? boolean @ 选项详细描述
---@param all_choices? string[] @ 所有选项（不可选变灰）
---@return string @ 选择的选项
function Room:askForChoice(player, choices, skill_name, prompt, detailed, all_choices)
  if #choices == 1 and not all_choices then return choices[1] end
  assert(not all_choices or table.every(choices, function(c) return table.contains(all_choices, c) end))
  local command = "AskForChoice"
  prompt = prompt or ""
  all_choices = all_choices or choices
  self:notifyMoveFocus(player, skill_name)
  local result = self:doRequest(player, command, json.encode{
    choices, all_choices, skill_name, prompt, detailed
  })
  if result == "" then
    if table.contains(choices, "Cancel") then
      result = "Cancel"
    else
      result = choices[1]
    end
  end
  return result
end

--- 询问一名玩家从众多选项中勾选任意项。
---@param player ServerPlayer @ 要询问的玩家
---@param choices string[] @ 可选选项列表
---@param minNum number @ 最少选择项数
---@param maxNum number @ 最多选择项数
---@param skill_name? string @ 技能名
---@param prompt? string @ 提示信息
---@param cancelable? boolean @ 是否可取消
---@param detailed? boolean @ 选项详细描述
---@param all_choices? string[] @ 所有选项（不可选变灰）
---@return string[] @ 选择的选项
function Room:askForChoices(player, choices, minNum, maxNum, skill_name, prompt, cancelable, detailed, all_choices)
  cancelable = (cancelable == nil) and true or cancelable
  if #choices <= minNum and not all_choices and not cancelable then return choices end
  assert(minNum <= maxNum)
  assert(not all_choices or table.every(choices, function(c) return table.contains(all_choices, c) end))
  local command = "AskForChoices"
  skill_name = skill_name or ""
  prompt = prompt or ""
  all_choices = all_choices or choices
  detailed = detailed or false
  self:notifyMoveFocus(player, skill_name)
  local result = self:doRequest(player, command, json.encode{
    choices, all_choices, {minNum, maxNum}, cancelable, skill_name, prompt, detailed
  })
  if result == "" then
    if cancelable then
      return {}
    else
      return table.random(choices, math.min(minNum, #choices))
    end
  end
  return json.decode(result)
end

--- 询问玩家是否发动技能。
---@param player ServerPlayer @ 要询问的玩家
---@param skill_name string @ 技能名
---@param data? any @ 未使用
---@param prompt? string @ 提示信息
---@return boolean
function Room:askForSkillInvoke(player, skill_name, data, prompt)
  local command = "AskForSkillInvoke"
  self:notifyMoveFocus(player, skill_name)
  local invoked = false
  local result = self:doRequest(player, command, json.encode{ skill_name, prompt })
  if result ~= "" then invoked = true end
  return invoked
end

-- 获取使用牌的合法额外目标（【借刀杀人】等带副目标的卡牌除外）
---@param data CardUseStruct @ 使用事件的data
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
      if data.card.skill:modTargetFilter(p.id, {}, data.from, data.card, not bypass_distances) then
        table.insert(tos, p.id)
      end
    end
  end
  return tos
end

--为使用牌增减目标
---@param player ServerPlayer @ 执行的玩家
---@param targets ServerPlayer[] @ 可选的目标范围
---@param num integer @ 可选的目标数
---@param can_minus boolean @ 是否可减少
---@param distance_limited boolean @ 是否受距离限制
---@param prompt string @ 提示信息
---@param skillName string @ 技能名
---@param data CardUseStruct @ 使用数据
function Room:askForAddTarget(player, targets, num, can_minus, distance_limited, prompt, skillName, data)
  num = num or 1
  can_minus = can_minus or false
  prompt = prompt or ""
  skillName = skillName or ""
  local room = player.room
  local tos = {}
  local orig_tos = table.simpleClone(AimGroup:getAllTargets(data.tos))
  if can_minus and #orig_tos > 1 then  --默认不允许减目标至0
    tos = table.map(table.filter(targets, function(p)
      return table.contains(AimGroup:getAllTargets(data.tos), p.id) end), Util.IdMapper)
  end
  for _, p in ipairs(targets) do
    if not table.contains(AimGroup:getAllTargets(data.tos), p.id) and not room:getPlayerById(data.from):isProhibited(p, data.card) then
      if data.card.skill:modTargetFilter(p.id, orig_tos, data.from, data.card, distance_limited) then
        table.insertIfNeed(tos, p.id)
      end
    end
  end
  if #tos > 0 then
    tos = room:askForChoosePlayers(player, tos, 1, num, prompt, skillName, true)
    --借刀……！
    if data.card.name ~= "collateral" then
      return tos
    else
      local result = {}
      for _, id in ipairs(tos) do
        local to = room:getPlayerById(id)
        local target = room:askForChoosePlayers(player, table.map(table.filter(room:getOtherPlayers(player), function(v)
          return to:inMyAttackRange(v) end), function(p) return p.id end), 1, 1,
          "#collateral-choose::"..to.id..":"..data.card:toLogString(), "collateral_skill", true)
        if #target > 0 then
          table.insert(result, {id, target[1]})
        end
      end
      if #result > 0 then
        return result
      else
        return {}
      end
    end
  end
  return {}
end

--- 询问玩家在自定义大小的框中排列卡牌（观星、交换、拖拽选牌）
---@param player ServerPlayer @ 要询问的玩家
---@param skillname string @ 烧条技能名
---@param cardMap any @ { "牌堆1卡表", "牌堆2卡表", …… }
---@param prompt? string @ 操作提示
---@param box_size? integer @ 数值对应卡牌平铺张数的最大值，为0则有单个卡位，每张卡占100单位长度，默认为7
---@param max_limit? integer[] @ 每一行牌上限 { 第一行, 第二行，…… }，不填写则不限
---@param min_limit? integer[] @ 每一行牌下限 { 第一行, 第二行，…… }，不填写则不限
---@param free_arrange? boolean @ 是否允许自由排列第一行卡的位置，默认不能
---@param pattern? string @ 控制第一行卡牌是否可以操作，不填写默认均可操作
---@param poxi_type? string @ 控制每张卡牌是否可以操作、确定键是否可以点击，不填写默认均可操作
---@param default_choice? table[] @ 超时的默认响应值，在带poxi_type时需要填写
---@return table[]
function Room:askForArrangeCards(player, skillname, cardMap, prompt, free_arrange, box_size, max_limit, min_limit, pattern, poxi_type, default_choice)
  prompt = prompt or ""
  local areaNames = {}
  if type(cardMap[1]) == "number" then
    cardMap = {cardMap}
  else
    for i = #cardMap, 1, -1 do
      if type(cardMap[i]) == "string" then
        table.insert(areaNames, 1, cardMap[i])
        table.remove(cardMap, i)
      end
    end
  end
  if #areaNames == 0 then
    areaNames = {skillname, "toObtain"}
  end
  box_size = box_size or 7
  max_limit = max_limit or {#cardMap[1], #cardMap > 1 and #cardMap[2] or #cardMap[1]}
  min_limit = min_limit or {0, 0}
  for _ = #cardMap + 1, #min_limit, 1 do
    table.insert(cardMap, {})
  end
  pattern = pattern or "."
  poxi_type = poxi_type or ""
  local command = "AskForArrangeCards"
  local data = {
    cards = cardMap,
    names = areaNames,
    prompt = prompt,
    size = box_size,
    capacities = max_limit,
    limits = min_limit,
    is_free = free_arrange or false,
    pattern = pattern or ".",
    poxi_type = poxi_type or "",
    cancelable = ((pattern ~= "." or poxi_type ~= "") and (default_choice == nil))
  }
  local result = self:doRequest(player, command, json.encode(data))
  -- local result = player.room:askForCustomDialog(player, skillname,
  -- "RoomElement/ArrangeCardsBox.qml", {
  --   cardMap, prompt, box_size, max_limit, min_limit, free_arrange or false, areaNames,
  --   pattern or ".", poxi_type or "", ((pattern ~= "." or poxi_type ~= "") and (default_choice == nil))
  -- })
  if result == "" then
    if default_choice then return default_choice end
    for j = 1, #min_limit, 1 do
      if #cardMap[j] < min_limit[j] then
        local cards = {table.connect(table.unpack(cardMap))}
        if #min_limit > 1 then
          for i = 2, #min_limit, 1 do
            table.insert(cards, {})
            if #cards[i] < min_limit[i] then
              for _ = 1, min_limit[i] - #cards[i], 1 do
                table.insert(cards[i], table.remove(cards[1], #cards[1] + #cards[i] - min_limit[i] + 1))
              end
            end
          end
          if #cards[1] > max_limit[1] then
            for i = 2, #max_limit, 1 do
              while #cards[i] < max_limit[i] do
                table.insert(cards[i], table.remove(cards[1], max_limit[1] + 1))
                if #cards[1] == max_limit[1] then return cards end
              end
            end
          end
        end
        return cards
      end
    end
    return cardMap
  end
  return json.decode(result)
end

-- TODO: guanxing type
--- 询问玩家对若干牌进行观星。
---
--- 观星完成后，相关的牌会被置于牌堆顶或者牌堆底。所以这些cards最好不要来自牌堆，一般先用getNCards从牌堆拿出一些牌。
---@param player ServerPlayer @ 要询问的玩家
---@param cards integer[] @ 可以被观星的卡牌id列表
---@param top_limit? integer[] @ 置于牌堆顶的牌的限制(下限,上限)，不填写则不限
---@param bottom_limit? integer[] @ 置于牌堆底的牌的限制(下限,上限)，不填写则不限
---@param customNotify? string @ 自定义读条操作提示
---param prompt? string @ 观星框的标题(暂时雪藏)
---@param noPut? boolean @ 是否进行放置牌操作
---@param areaNames? string[] @ 左侧提示信息
---@return table<"top"|"bottom", integer[]>
function Room:askForGuanxing(player, cards, top_limit, bottom_limit, customNotify, noPut, areaNames)
  -- 这一大堆都是来提前报错的
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
  if areaNames then
    assert(#areaNames == 2, "areaNames error: Should have 2 elements")
  else
    areaNames =  { "Top", "Bottom" }
  end
  local command = "AskForGuanxing"
  self:notifyMoveFocus(player, customNotify or command)
  local max_top = top_limit[2]
  local card_map = {}
  if max_top > 0 then
    table.insert(card_map, table.slice(cards, 1, max_top + 1))
  end
  if max_top < leng then
    table.insert(card_map, table.slice(cards, max_top + 1))
  end
  local data = {
    prompt = "",
    is_free = true,
    cards = card_map,
    min_top_cards = top_limit[1],
    max_top_cards = top_limit[2],
    min_bottom_cards = bottom_limit[1],
    max_bottom_cards = bottom_limit[2],
    top_area_name = areaNames[1],
    bottom_area_name = areaNames[2],
  }

  local result = self:doRequest(player, command, json.encode(data))
  local top, bottom
  if result ~= "" then
    local d = json.decode(result)
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
      table.insert(self.draw_pile, 1, top[i])
    end
    for i = 1, #bottom, 1 do
      table.insert(self.draw_pile, bottom[i])
    end

    self:sendLog{
      type = "#GuanxingResult",
      from = player.id,
      arg = #top,
      arg2 = #bottom,
    }
  end

  return { top = top, bottom = bottom }
end

--- 询问玩家任意交换几堆牌堆。
---
---@param player ServerPlayer @ 要询问的玩家
---@param piles (integer[])[] @ 卡牌id列表的列表，也就是……几堆牌堆的集合
---@param piles_name string[] @ 牌堆名，不足部分替换为“牌堆1、牌堆2...”
---@param customNotify? string @ 自定义读条操作提示
---@return (integer[])[]
function Room:askForExchange(player, piles, piles_name, customNotify)
  local command = "AskForExchange"
  piles_name = piles_name or Util.DummyTable
  local x = #piles - #piles_name
  if x > 0 then
    for i = 1, x, 1 do
      table.insert(piles_name, Fk:translate("Pile") .. i)
    end
  elseif x < 0 then
    piles_name = table.slice(piles_name, 1, #piles + 1)
  end
  self:notifyMoveFocus(player, customNotify or command)
  local data = {
    piles = piles,
    piles_name = piles_name,
  }
  local result = self:doRequest(player, command, json.encode(data))
  if result ~= "" then
    local d = json.decode(result)
    return d
  else
    return piles
  end
end
--- 平时写DIY用不到的函数。
---@param player ServerPlayer
---@param data string
---@return CardUseStruct
function Room:handleUseCardReply(player, data)
  data = json.decode(data)
  local card = data.card
  local targets = data.targets
  if type(card) == "string" then
    local card_data = json.decode(card)
    local skill = Fk.skills[card_data.skill]
    local selected_cards = card_data.subcards
    if skill.interaction then skill.interaction.data = data.interaction_data end
    if skill:isInstanceOf(ActiveSkill) then
      self:useSkill(player, skill, function()
        skill:onUse(self, {
          from = player.id,
          cards = selected_cards,
          tos = targets,
        })
      end, {tos = targets, cards = selected_cards, cost_data = {}})
      return nil
    elseif skill:isInstanceOf(ViewAsSkill) then
      Self = player
      local c = skill:viewAs(selected_cards)
      if c then
        local use = {}    ---@type CardUseStruct
        use.from = player.id
        use.tos = {}
        for _, target in ipairs(targets) do
          table.insert(use.tos, { target })
        end
        if #use.tos == 0 then
          use.tos = nil
        end
        use.card = c

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
      skill:onUse(self, {
        from = player.id,
        cards = { card },
        tos = targets,
      })
      return nil
    end
    local use = {}    ---@type CardUseStruct
    use.from = player.id
    use.tos = {}
    for _, target in ipairs(targets or Util.DummyTable) do
      table.insert(use.tos, { target })
    end
    if #use.tos == 0 then
      use.tos = nil
    end
    Fk:filterCard(card, player)
    use.card = Fk:getCardById(card)
    return use
  end
end

-- available extra_data:
-- * must_targets: integer[]
-- * exclusive_targets: integer[]
-- * bypass_distances: boolean
-- * bypass_times: boolean
---
--- 询问玩家使用一张牌。
---@param player ServerPlayer @ 要询问的玩家
---@param card_name? string @ 使用牌的牌名，若pattern指定了则可随意写，它影响的是烧条的提示信息
---@param pattern? string @ 使用牌的规则，默认就是card_name的值
---@param prompt? string @ 提示信息
---@param cancelable? boolean @ 能否点取消
---@param extra_data? UseExtraData @ 额外信息
---@param event_data? CardEffectEvent @ 事件信息
---@return CardUseStruct? @ 返回关于本次使用牌的数据，以便后续处理
function Room:askForUseCard(player, card_name, pattern, prompt, cancelable, extra_data, event_data)
  pattern = pattern or card_name
  if event_data and (event_data.disresponsive or table.contains(event_data.disresponsiveList or Util.DummyTable, player.id)) then
    return nil
  end

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
  self:notifyMoveFocus(player, card_name)
  cancelable = (cancelable == nil) and true or cancelable
  extra_data = extra_data or Util.DummyTable
  prompt = prompt or ""

  local askForUseCardData = {
    user = player,
    cardName = card_name,
    pattern = pattern,
    extraData = extra_data,
    eventData = event_data,
  }
  self.logic:trigger(fk.AskForCardUse, player, askForUseCardData)

  local useResult
  if askForUseCardData.result and type(askForUseCardData.result) == 'table' then
    useResult = askForUseCardData.result
  else
    local disabledSkillNames = {}

    repeat
      useResult = nil
      local data = {card_name, pattern, prompt, cancelable, extra_data, disabledSkillNames}

      Fk.currentResponsePattern = pattern
      self.logic:trigger(fk.HandleAskForPlayCard, nil, askForUseCardData, true)
      local result = self:doRequest(player, command, json.encode(data))
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
---@param card_name string @ 牌名
---@param pattern? string @ 牌的规则
---@param prompt? string @ 提示信息
---@param cancelable? boolean @ 能否取消
---@param extra_data? any @ 额外数据
---@param effectData? CardEffectEvent @ 关联的卡牌生效流程
---@return Card? @ 打出的牌
function Room:askForResponse(player, card_name, pattern, prompt, cancelable, extra_data, effectData)
  if effectData and (effectData.disresponsive or table.contains(effectData.disresponsiveList or Util.DummyTable, player.id)) then
    return nil
  end

  local command = "AskForResponseCard"
  self:notifyMoveFocus(player, card_name)
  cancelable = (cancelable == nil) and true or cancelable
  extra_data = extra_data or Util.DummyTable
  pattern = pattern or card_name
  prompt = prompt or ""

  local eventData = {
    user = player,
    cardName = card_name,
    pattern = pattern,
    extraData = extra_data,
    eventData = effectData,
  }
  self.logic:trigger(fk.AskForCardResponse, player, eventData)

  local responseResult
  if eventData.result then
    responseResult = eventData.result
  else
    local disabledSkillNames = {}

    repeat
      responseResult = nil
      local data = {card_name, pattern, prompt, cancelable, extra_data, disabledSkillNames}

      Fk.currentResponsePattern = pattern
      eventData.isResponse = true
      self.logic:trigger(fk.HandleAskForPlayCard, nil, eventData, true)
      local result = self:doRequest(player, command, json.encode(data))
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
---@param card_name string @ 询问的牌名，默认为无懈
---@param pattern string @ 牌的规则
---@param prompt? string @ 提示信息
---@param cancelable? boolean @ 能否点取消
---@param extra_data? any @ 额外信息
---@param effectData? CardEffectEvent @ 关联的卡牌生效流程
---@return CardUseStruct? @ 最终决胜出的卡牌使用信息
function Room:askForNullification(players, card_name, pattern, prompt, cancelable, extra_data, effectData)
  if #players == 0 then
    self.logic:trigger(fk.AfterAskForNullification, nil, { eventData = effectData })
    return nil
  end

  local command = "AskForUseCard"
  card_name = card_name or "nullification"
  cancelable = (cancelable == nil) and true or cancelable
  extra_data = extra_data or Util.DummyTable
  prompt = prompt or ""
  pattern = pattern or card_name

  local useResult
  local disabledSkillNames = {}

  repeat
    useResult = nil
    self:notifyMoveFocus(self.alive_players, card_name)
    self:doBroadcastNotify("WaitForNullification", "")

    local data = {card_name, pattern, prompt, cancelable, extra_data, disabledSkillNames}

    Fk.currentResponsePattern = pattern

    local eventData = {
      cardName = card_name,
      pattern = pattern,
      extraData = extra_data,
      eventData = effectData,
    }
    self.logic:trigger(fk.HandleAskForPlayCard, nil, eventData, true)
    local winner = self:doRaceRequest(command, players, json.encode(data))
    eventData.afterRequest = true
    self.logic:trigger(fk.HandleAskForPlayCard, nil, eventData, true)

    if winner then
      local result = winner.client_reply
      useResult = self:handleUseCardReply(winner, result)

      if type(useResult) == "string" and useResult ~= "" then
        table.insertIfNeed(disabledSkillNames, useResult)
      end
    end
    Fk.currentResponsePattern = nil
  until type(useResult) ~= "string"

  local askForNullificationData = {
    result = useResult,
    eventData = effectData,
  }
  self.logic:trigger(fk.AfterAskForNullification, nil, askForNullificationData)
  return useResult
end

-- AG(a.k.a. Amazing Grace) functions
-- Popup a box that contains many cards, then ask player to choose one

--- 询问玩家从AG中选择一张牌。
---@param player ServerPlayer @ 要询问的玩家
---@param id_list integer[] | Card[] @ 可选的卡牌列表
---@param cancelable? boolean @ 能否点取消
---@param reason? string @ 原因
---@return integer @ 选择的卡牌
function Room:askForAG(player, id_list, cancelable, reason)
  id_list = Card:getIdList(id_list)
  if #id_list == 1 and not cancelable then
    return id_list[1]
  end

  local command = "AskForAG"
  self:notifyMoveFocus(player, reason or command)
  local data = { id_list, cancelable, reason }
  local ret = self:doRequest(player, command, json.encode(data))
  if ret == "" and not cancelable then
    ret = table.random(id_list)
  end
  return tonumber(ret)
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

-- TODO: 重构request机制，不然这个还得手动拿client_reply
---@param players ServerPlayer[]
---@param focus string
---@param game_type string
---@param data_table table<integer, any> @ 对应每个player
function Room:askForMiniGame(players, focus, game_type, data_table)
  local command = "MiniGame"
  local game = Fk.mini_games[game_type]
  if #players == 0 or not game then return end
  for _, p in ipairs(players) do
    local data = data_table[p.id]
    p.mini_game_data = { type = game_type, data = data }
    p.request_data = json.encode(p.mini_game_data)
    p.default_reply = game.default_choice and json.encode(game.default_choice(p, data)) or ""
  end

  self:notifyMoveFocus(players, focus)
  self:doBroadcastRequest(command, players)

  for _, p in ipairs(players) do
    p.mini_game_data = nil
    if not p.reply_ready then
      p.client_reply = p.default_reply
      p.reply_ready = true
    end
  end
end

-- Show a qml dialog and return qml's ClientInstance.replyToServer
-- Do anything you like through this function

-- 调用一个自定义对话框，须自备loadData方法
---@param player ServerPlayer
---@param focustxt string
---@param qmlPath string
---@param extra_data any
---@return string
function Room:askForCustomDialog(player, focustxt, qmlPath, extra_data)
  local command = "CustomDialog"
  self:notifyMoveFocus(player, focustxt)
  return self:doRequest(player, command, json.encode{
    path = qmlPath,
    data = extra_data,
  })
end

--- 询问移动场上的一张牌
---@param player ServerPlayer @ 移动的操作
---@param targetOne ServerPlayer @ 移动的目标1玩家
---@param targetTwo ServerPlayer @ 移动的目标2玩家
---@param skillName string @ 技能名
---@param flag? string @ 限定可移动的区域，值为nil（装备区和判定区）、‘e’或‘j’
---@param moveFrom? ServerPlayer @ 是否只是目标1移动给目标2
---@param excludeIds? integer[] @ 本次不可移动的卡牌id
---@return table<"card"|"from"|"to">? @ 选择的卡牌、起点玩家id和终点玩家id列表
function Room:askForMoveCardInBoard(player, targetOne, targetTwo, skillName, flag, moveFrom, excludeIds)
  if flag then
    assert(flag == "e" or flag == "j")
  end

  excludeIds = type(excludeIds) == "table" and excludeIds or {}

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
  self:notifyMoveFocus(player, command)
  local result = self:doRequest(player, command, json.encode(data))

  if result == "" then
    local randomIndex = math.random(1, #cards)
    result = { cardId = cards[randomIndex], pos = cardsPosition[randomIndex] }
  else
    result = json.decode(result)
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

--- 询问一名玩家从targets中选择出若干名玩家来移动场上的牌。
---@param player ServerPlayer @ 要做选择的玩家
---@param prompt string @ 提示信息
---@param skillName string @ 技能名
---@param cancelable? boolean @ 是否可以取消选择
---@param flag? string @ 限定可移动的区域，值为nil（装备区和判定区）、‘e’或‘j’
---@param no_indicate? boolean @ 是否不显示指示线
---@return integer[] @ 选择的玩家id列表，可能为空
function Room:askForChooseToMoveCardInBoard(player, prompt, skillName, cancelable, flag, no_indicate, excludeIds)
  if flag then
    assert(flag == "e" or flag == "j")
  end
  cancelable = (cancelable == nil) and true or cancelable
  no_indicate = (no_indicate == nil) and true or no_indicate
  excludeIds = type(excludeIds) == "table" and excludeIds or {}

  local data = {
    flag = flag,
    skillName = skillName,
    excludeIds = excludeIds,
  }
  local _, ret = self:askForUseActiveSkill(
    player,
    "choose_players_to_move_card_in_board",
    prompt or "",
    cancelable,
    data,
    no_indicate
  )

  if ret then
    return ret.targets
  else
    if cancelable then
      return {}
    else
      return self:canMoveCardInBoard(flag, excludeIds)
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
  local players = {}
  local p = 0

  for i = 1, #self.players do
    if self.players[i].role == "lord" then
      p = i
      break
    end
  end
  for j = p, #self.players do
    table.insert(players, self.players[j])
  end
  for j = 1, p - 1 do
    table.insert(players, self.players[j])
  end

  self.players = players

  local player_circle = {}
  for i = 1, #self.players do
    self.players[i].seat = i
    table.insert(player_circle, self.players[i].id)
  end

  self:doBroadcastNotify("ArrangeSeats", json.encode(player_circle))
end

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
  a.seat, b.seat = b.seat, a.seat

  local player_circle = {}
  for _, v in ipairs(players) do
    table.insert(player_circle, v.id)
  end

  for i = 1, #players - 1 do
    players[i].next = players[i + 1]
  end
  players[#players].next = players[1]

  self:doBroadcastNotify("ArrangeSeats", json.encode(player_circle))
end

--- 洗牌。
function Room:shuffleDrawPile()
  local seed = math.random(2 << 32 - 1)
  AbstractRoom.shuffleDrawPile(self, seed)

  -- self:doBroadcastNotify("UpdateDrawPile", #self.draw_pile)
  self:doBroadcastNotify("ShuffleDrawPile", seed)

  self.logic:trigger(fk.AfterDrawPileShuffle, nil, {})
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

  for _, p in ipairs(self.players) do
    self:broadcastProperty(p, "role")
  end
  self:doBroadcastNotify("GameOver", winner)
  fk.qInfo(string.format("[GameOver] %d, %s, %s, in %ds", self.id, self.settings.gameMode, winner, os.time() - self.start_time))

  if shouldUpdateWinRate(self) then
    for _, p in ipairs(self.players) do
      local id = p.id
      local general = p.general
      local mode = self.settings.gameMode

      if p.id > 0 then
        if table.contains(winner:split("+"), p.role) then
          self.room:updateWinRate(id, general, mode, 1, p.dead)
        elseif winner == "" then
          self.room:updateWinRate(id, general, mode, 3, p.dead)
        else
          self.room:updateWinRate(id, general, mode, 2, p.dead)
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

---@param flag? string
---@param players? ServerPlayer[]
---@param excludeIds? integer[]
---@return integer[] @ 玩家id列表 可能为空
function Room:canMoveCardInBoard(flag, players, excludeIds)
  if flag then
    assert(flag == "e" or flag == "j")
  end

  players = players or self.alive_players
  excludeIds = type(excludeIds) == "table" and excludeIds or {}

  local targets = {}
  table.find(players, function(p)
    local canMoveTo = table.find(players, function(another)
      return p ~= another and p:canMoveCardsInBoardTo(another, flag, excludeIds)
    end)

    if canMoveTo then
      targets = {p.id, canMoveTo.id}
    end
    return canMoveTo
  end)

  return targets
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
    from = player.id,
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

--- 为角色或牌的表型标记移除值
---@param sth ServerPlayer|Card @ 更新标记的玩家或卡牌
---@param mark string @ 标记的名称
---@param value any @ 要移除的值
function Room:removeTableMark(sth, mark, value)
  local t = sth:getTableMark(mark)
  table.removeOne(t, value)
  if sth:isInstanceOf(Card) then
    self:setCardMark(sth, mark, #t > 0 and t or 0)
  else
    self:setPlayerMark(sth, mark, #t > 0 and t or 0)
  end
end

function Room:__index(k)
  if k == "room_settings" then
    return self.settings
  end
end

return Room
