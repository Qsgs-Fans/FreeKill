-- SPDX-License-Identifier: GPL-3.0-or-later

--- Room是fk游戏逻辑运行的主要场所，同时也提供了许多API函数供编写技能使用。
---
--- 一个房间中只有一个Room实例，保存在RoomInstance全局变量中。
---@class Room : Object
---@field public room fk.Room @ C++层面的Room类实例，别管他就是了，用不着
---@field public id integer @ 房间的id
---@field private main_co any @ 本房间的主协程
---@field public players ServerPlayer[] @ 这个房间中所有参战玩家
---@field public alive_players ServerPlayer[] @ 所有还活着的玩家
---@field public observers fk.ServerPlayer[] @ 旁观者清单，这是c++玩家列表，别乱动
---@field public current ServerPlayer @ 当前回合玩家
---@field public game_started boolean @ 游戏是否已经开始
---@field public game_finished boolean @ 游戏是否已经结束
---@field public timeout integer @ 出牌时长上限
---@field public tag table<string, any> @ Tag清单，其实跟Player的标记是差不多的东西
---@field public general_pile string[] @ 武将牌堆，这是可用武将名的数组
---@field public draw_pile integer[] @ 摸牌堆，这是卡牌id的数组
---@field public discard_pile integer[] @ 弃牌堆，也是卡牌id的数组
---@field public processing_area integer[] @ 处理区，依然是卡牌id数组
---@field public void integer[] @ 从游戏中除外区，一样的是卡牌id数组
---@field public card_place table<integer, CardArea> @ 每个卡牌的id对应的区域，一张表
---@field public owner_map table<integer, integer> @ 每个卡牌id对应的主人，表的值是那个玩家的id，可能是nil
---@field public status_skills Skill[] @ 这个房间中含有的状态技列表
---@field public settings table @ 房间的额外设置，差不多是json对象
---@field public logic GameLogic @ 这个房间使用的游戏逻辑，可能根据游戏模式而变动
---@field public request_queue table<userdata, table>
---@field public request_self table<integer, integer>
---@field public skill_costs table<string, any> @ 存放skill.cost_data用
---@field public card_marks table<integer, any> @ 存放card.mark之用
local Room = class("Room")

-- load classes used by the game
GameEvent = require "server.gameevent"
dofile "lua/server/events/init.lua"
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
]]----------------------------------------------------------------------

------------------------------------------------------------------------
-- 构造函数
------------------------------------------------------------------------

--- 构造函数。别去构造
---@param _room fk.Room
function Room:initialize(_room)
  self.room = _room
  self.id = _room:getId()

  self.players = {}
  self.alive_players = {}
  self.observers = {}
  self.current = nil
  self.game_started = false
  self.game_finished = false
  self.timeout = _room:getTimeout()
  self.tag = {}
  self.general_pile = {}
  self.draw_pile = {}
  self.discard_pile = {}
  self.processing_area = {}
  self.void = {}
  self.card_place = {}
  self.owner_map = {}
  self.status_skills = {}
  for class, skills in pairs(Fk.global_status_skill) do
    self.status_skills[class] = {table.unpack(skills)}
  end
  self.request_queue = {}
  self.request_self = {}
  self.skill_costs = {}
  self.card_marks = {}
  self.filtered_cards = {}
  self.printed_cards = {}

  self.settings = json.decode(self.room:settings())
  self.disabled_packs = self.settings.disabledPack
  if not Fk.game_modes[self.settings.gameMode] then
    self.settings.gameMode = "aaa_role_mode"
  end

  table.insertTable(self.disabled_packs, Fk.game_mode_disabled[self.settings.gameMode])
  self.disabled_generals = self.settings.disabledGenerals
end

-- 供调度器使用的函数。能让房间开始运行/从挂起状态恢复。
function Room:resume()
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
    return true
  end

  if not self.game_finished then
    ret, err_msg, rest_time = coroutine.resume(main_co, err_msg)

    -- handle error
    if ret == false then
      fk.qCritical(err_msg)
      print(debug.traceback(main_co))
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

-- 供调度器使用的函数，用来指示房间是否就绪。
-- 如果没有就绪的话，可能会返回第二个值来告诉调度器自己还有多久就绪。
function Room:isReady()
  -- 没有活人了？那就告诉调度器我就绪了，恢复时候就会自己杀掉
  if self:checkNoHuman(true) then
    return true
  end

  -- 因为delay函数而延时：判断延时是否已经结束。
  -- 注意整个delay函数的实现都搬到这来了，delay本身只负责挂起协程了。
  if self.in_delay then
    local rest = self.delay_duration - (os.getms() - self.delay_start) / 1000
    if rest <= 0 then
      self.in_delay = false
      return true
    end
    return false, rest
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
      ret = false
      -- 烧条烧光了的话就把thinking设为false
      rest = p.request_timeout * 1000 - (os.getms() -
        p.request_start) / 1000

      if rest <= 0 or p.serverplayer:getState() ~= fk.Player_Online then
        p._splayer:setThinking(false)
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
  self.logic = (mode.logic and mode.logic() or GameLogic):new(self)
  if mode.rule then self.logic:addTriggerSkill(mode.rule) end
  self.logic:run()
end

------------------------------------------------------------------------
-- getters/setters
------------------------------------------------------------------------

--- 基本算是私有函数，别去用
---@param cardId integer
---@param cardArea CardArea
---@param owner nil|integer
function Room:setCardArea(cardId, cardArea, owner)
  self.card_place[cardId] = cardArea
  self.owner_map[cardId] = owner
end

--- 获取一张牌所处的区域。
---@param cardId integer | Card @ 要获得区域的那张牌，可以是Card或者一个id
---@return CardArea @ 这张牌的区域
function Room:getCardArea(cardId)
  if type(cardId) ~= "number" then
    assert(cardId and cardId:isInstanceOf(Card))
    cardId = cardId:getEffectiveId()
  end
  return self.card_place[cardId] or Card.Unknown
end

--- 获得拥有某一张牌的玩家。
---@param cardId integer | card @ 要获得主人的那张牌，可以是Card实例或者id
---@return ServerPlayer | nil @ 这张牌的主人，可能返回nil
function Room:getCardOwner(cardId)
  if type(cardId) ~= "number" then
    assert(cardId and cardId:isInstanceOf(Card))
    cardId = cardId:getEffectiveId()
  end
  return self.owner_map[cardId] and self:getPlayerById(self.owner_map[cardId]) or nil
end

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

--- 将房间中的玩家按照座位顺序重新排序。
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
---@param sortBySeat bool @ 是否无视按座位排序直接返回
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
---@param sortBySeat bool
---@return ServerPlayer[]
function Room:getAlivePlayers(sortBySeat)
  if sortBySeat == nil or sortBySeat then
    local current = self.current
    local temp = current.next

    -- did not arrange seat, use default
    if temp == nil then
      return { table.unpack(self.players) }
    end
    local ret = {current}
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
---@param sortBySeat bool @ 是否要按座位排序？
---@param include_dead bool @ 是否要把死人也算进去？
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
---@return ServerPlayer | nil @ 主公
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
---@param from string|nil @ 获得牌的位置，可以是 ``"top"`` 或者 ``"bottom"``，表示牌堆顶还是牌堆底
---@return integer[] @ 得到的id
function Room:getNCards(num, from)
  from = from or "top"
  assert(from == "top" or from == "bottom")

  local cardIds = {}
  while num > 0 do
    if #self.draw_pile < 1 then
      self:shuffleDrawPile()
      if #self.draw_pile < 1 then
        self:gameOver("")
      end
    end

    local index = from == "top" and 1 or #self.draw_pile
    table.insert(cardIds, self.draw_pile[index])
    table.remove(self.draw_pile, index)

    num = num - 1
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
---@param count integer | nil @ 要增加的数量，默认为1
function Room:addPlayerMark(player, mark, count)
  count = count or 1
  local num = player:getMark(mark)
  num = num or 0
  self:setPlayerMark(player, mark, math.max(num + count, 0))
end

--- 将一名玩家的mark标记减少count个。
---@param player ServerPlayer @ 要减标记的玩家
---@param mark string @ 标记名称
---@param count integer | nil @ 要减少的数量，默认为1
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
---@param count integer | nil @ 要增加的数量，默认为1
function Room:addCardMark(card, mark, count)
  count = count or 1
  local num = card:getMark(mark)
  num = num or 0
  self:setCardMark(card, mark, math.max(num + count, 0))
end

--- 将一名玩家的mark标记减少count个。
---@param card Card @ 要被减少标记的那张牌
---@param mark string @ 标记名称
---@param count integer | nil @ 要减少的数量，默认为1
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

local function execGameEvent(type, ...)
  local event = GameEvent:new(type, ...)
  local _, ret = event:exec()
  return ret
end

---@param player ServerPlayer
---@param general string
---@param changeKingdom bool
---@param noBroadcast bool
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

---@param player ServerPlayer @ 要换将的玩家
---@param new_general string @ 要变更的武将，若不存在则变身为孙策，孙策不存在变身为士兵
---@param full bool @ 是否血量满状态变身
---@param isDeputy bool @ 是否变的是副将
---@param sendLog bool @ 是否发Log
---@param maxHpChange bool @ 是否改变体力上限，默认改变
function Room:changeHero(player, new_general, full, isDeputy, sendLog, maxHpChange)
  local new = Fk.generals[new_general] or Fk.generals["sunce"] or Fk.generals["blank_shibing"]

  local kingdom = isDeputy and player.kingdom or new.kingdom
  if not isDeputy and (new.kingdom == "god" or new.subkingdom) then
    local allKingdoms = {}
    if new.kingdom == "god" then
      allKingdoms = {"wei", "shu", "wu", "qun", "jin"}
    elseif new.subkingdom then
      allKingdoms = { new.kingdom, new.subkingdom }
    end
    kingdom = self:askForChoice(player, allKingdoms, "AskForKingdom", "#ChooseInitialKingdom")
  end

  execGameEvent(GameEvent.ChangeProperty,
  {
    from = player,
    general = not isDeputy and new_general or "",
    deputyGeneral = isDeputy and new_general or "",
    gender = isDeputy and player.gender or new.gender,
    kingdom = kingdom,
    sendLog = sendLog,
    results = {},
  })

  maxHpChange = (maxHpChange == nil) and true or maxHpChange
  if maxHpChange then
    self:setPlayerProperty(player, "maxHp", player:getGeneralMaxHp())
  end
  if full or player.hp > player.maxHp then
    self:setPlayerProperty(player, "hp", player.maxHp)
  end
end

---@param player ServerPlayer @ 要变更势力的玩家
---@param kingdom string @ 要变更的势力
---@param sendLog bool @ 是否发Log
function Room:changeKingdom(player, kingdom, sendLog)
  if kingdom == player.kingdom then return end
  sendLog = sendLog or false

  execGameEvent(GameEvent.ChangeProperty,
  {
    from = player,
    kingdom = kingdom,
    sendLog = sendLog,
    results = {},
  })
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
---@param players ServerPlayer[] | nil @ 要告知的玩家列表，默认为所有人
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
---@param wait bool @ 是否要等待答复，默认为true
---@return string | nil @ 收到的答复，如果wait为false的话就返回nil
function Room:doRequest(player, command, jsonData, wait)
  if wait == nil then wait = true end
  self.request_queue = {}
  self.race_request_list = nil
  player:doRequest(command, jsonData, self.timeout)

  if wait then
    local ret = player:waitForReply(self.timeout)
    player.serverplayer:setBusy(false)
    player.serverplayer:setThinking(false)
    return ret
  end
end

--- 向多名玩家发出请求。
---@param command string @ 请求类型
---@param players ServerPlayer[]|nil @ 发出请求的玩家列表
---@param jsonData string|nil @ 请求数据
function Room:doBroadcastRequest(command, players, jsonData)
  players = players or self.players
  self.request_queue = {}
  self.race_request_list = nil
  for _, p in ipairs(players) do
    p:doRequest(command, jsonData or p.request_data)
  end

  local remainTime = self.timeout
  local currentTime = os.time()
  local elapsed = 0
  for _, p in ipairs(players) do
    elapsed = os.time() - currentTime
    p:waitForReply(remainTime - elapsed)
  end

  for _, p in ipairs(players) do
    p.serverplayer:setBusy(false)
    p.serverplayer:setThinking(false)
  end
end

--- 向多名玩家发出竞争请求。
---
--- 他们都可以做出答复，但是服务器只认可第一个做出回答的角色。
---
--- 返回获胜的角色，可以通过属性获得回复的具体内容。
---@param command string @ 请求类型
---@param players ServerPlayer[] @ 要竞争这次请求的玩家列表
---@param jsonData string @ 请求数据
---@return ServerPlayer | nil @ 在这次竞争请求中获胜的角色，可能是nil
function Room:doRaceRequest(command, players, jsonData)
  players = players or self.players
  players = table.simpleClone(players)
  local player_len = #players
  -- self:notifyMoveFocus(players, command)
  self.request_queue = {}
  self.race_request_list = players
  for _, p in ipairs(players) do
    p:doRequest(command, jsonData or p.request_data)
  end

  local elapsed = 0
  local canceled_players = {}
  local ret = nil
  local remainTime = self.timeout
  local currentTime = os.time()
  while true do
    elapsed = os.time() - currentTime
    if remainTime - elapsed <= 0 then
      break
    end
    for _, p in ipairs(table.filter(players,function() return true end)) do
      p:waitForReply(0)
      if p.reply_ready == true then
        ret = p
        break
      end
      if p.reply_cancel then
        table.insertIfNeed(canceled_players, p)
        table.removeOne(players, p)
      elseif p.id > 0 then
        -- 骗过调度器让他以为自己尚未就绪
        p.request_timeout = remainTime - elapsed
        p.serverplayer:setThinking(true)
      end
    end
    if ret then
      self:doBroadcastNotify("CancelRequest", "")
      break
    end
    if #canceled_players >= player_len then
      break
    end
    coroutine.yield("__handleRequest", (remainTime - elapsed) * 1000)
  end

  for _, p in ipairs(self.players) do
    p.serverplayer:setBusy(false)
    p.serverplayer:setThinking(false)
  end
  if self.current and (ret == nil or ret.serverplayer:getState() ~= fk.Player_Online) then
    self:delay(math.random(233, 2333)) --无懈增加随机延迟，就难以察觉场上是否有无懈了
  end

  return ret
end


--- 延迟一段时间。
---
--- 这个函数不应该在请求处理协程中使用。
---@param ms integer @ 要延迟的毫秒数
function Room:delay(ms)
  local start = os.getms()
  self.delay_start = start
  self.delay_duration = ms
  self.in_delay = true
  coroutine.yield("__handleRequest", ms)
end

--- 向多名玩家告知一次移牌行为。
---@param players ServerPlayer[] | nil @ 要被告知的玩家列表，默认为全员
---@param card_moves CardsMoveStruct[] @ 要告知的移牌信息列表
---@param forceVisible bool @ 是否让所有牌对告知目标可见
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

      local function containArea(area, relevant) --处理区的处理？
        local areas = relevant
          and {Card.PlayerEquip, Card.PlayerJudge, Card.DiscardPile, Card.Processing, Card.PlayerHand, Card.PlayerSpecial}
          or {Card.PlayerEquip, Card.PlayerJudge, Card.DiscardPile, Card.Processing}
        return table.contains(areas, area)
      end

      -- forceVisible make the move visible
      -- if move is relevant to player's hands or equips, it should be open
        -- cards move from/to equip/judge/discard/processing should be open

      if not (move.moveVisible or forceVisible or containArea(move.toArea, move.to and p.isBuddy and p:isBuddy(move.to))) then
        for _, info in ipairs(move.moveInfo) do
          if not containArea(info.fromArea, move.from == p.id) then
          info.cardId = -1
        end
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
---@param players ServerPlayer[] | nil @ 要观看动画的玩家们，默认为全员
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
---@param index integer | nil @ 语音编号，默认为-1（也就是随机播放）
function Room:broadcastSkillInvoke(skill_name, index)
  print 'Room:broadcastSkillInvoke deprecated; use SPlayer:broadcastSkillInvoke'
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
---@param skill_type string | nil @ 技能的动画效果，默认是那个技能的anim_type
function Room:notifySkillInvoked(player, skill_name, skill_type)
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

  self:sendLog{
    type = "#InvokeSkill",
    from = player.id,
    arg = skill_name,
  }

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
---@param prompt string|nil @ 烧条上面显示的提示文本内容
---@param cancelable bool @ 是否可以点取消
---@param extra_data table|nil @ 额外信息，因技能而异了
---@param no_indicate bool @ 是否不显示指示线
---@return boolean, table
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
  local data = {skill_name, prompt, cancelable, json.encode(extra_data)}

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
  if not no_indicate then
    self:doIndicate(player.id, targets)
  end

  if skill.interaction then
    skill.interaction.data = data.interaction_data
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
    targets = targets
  }
end

Room.askForUseViewAsSkill = Room.askForUseActiveSkill

--- 询问一名角色弃牌。
---
--- 在这个函数里面牌已经被弃掉了（除非skipDiscard为true）。
---@param player ServerPlayer @ 弃牌角色
---@param minNum integer @ 最小值
---@param maxNum integer @ 最大值
---@param includeEquip bool @ 能不能弃装备区？
---@param skillName string|nil @ 引发弃牌的技能名
---@param cancelable bool @ 能不能点取消？
---@param pattern string|nil @ 弃牌需要符合的规则
---@param prompt string|nil @ 提示信息
---@param skipDiscard bool @ 是否跳过弃牌（即只询问选择可以弃置的牌）
---@param no_indicate bool @ 是否不显示指示线
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
    toDiscard = table.random(canDiscards, minNum)
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
---@param prompt string|nil @ 提示信息
---@param skillName string|nil @ 技能名
---@param cancelable bool @ 能否点取消
---@param no_indicate bool @ 是否不显示指示线
---@return integer[] @ 选择的玩家id列表，可能为空
function Room:askForChoosePlayers(player, targets, minNum, maxNum, prompt, skillName, cancelable, no_indicate)
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
    skillName = skillName
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
---@param includeEquip bool @ 能不能选装备
---@param skillName string @ 技能名
---@param cancelable bool @ 能否点取消
---@param pattern string|nil @ 选牌规则
---@param prompt string|nil @ 提示信息
---@param expand_pile string|nil @ 可选私人牌堆名称
---@param no_indicate bool @ 是否不显示指示线
---@return integer[] @ 选择的牌的id列表，可能是空的
function Room:askForCard(player, minNum, maxNum, includeEquip, skillName, cancelable, pattern, prompt, expand_pile, no_indicate)
  if minNum < 1 then
    return nil
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
  local prompt = prompt or ("#AskForCard:::" .. maxNum .. ":" .. minNum)
  local _, ret = self:askForUseActiveSkill(player, "choose_cards_skill", prompt, cancelable, data, no_indicate)
  if ret then
    chosenCards = ret.cards
  else
    if cancelable then return {} end
    local hands = player:getCardIds(Player.Hand)
    if includeEquip then
      table.insertTable(hands, player:getCardIds(Player.Equip))
    end
    local exp = Exppattern:Parse(pattern)
    hands = table.filter(hands, function(cid)
      return exp:match(Fk:getCardById(cid))
    end)
    for _ = 1, minNum do
      local randomId = hands[math.random(1, #hands)]
      table.insert(chosenCards, randomId)
      table.removeOne(hands, randomId)
    end
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
---@param pattern string|nil @ 选牌规则
---@param prompt string|nil @ 提示信息
---@param cancelable bool @ 能否点取消
---@param no_indicate bool @ 是否不显示指示线
---@return integer[], integer
function Room:askForChooseCardAndPlayers(player, targets, minNum, maxNum, pattern, prompt, skillName, cancelable, no_indicate)
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
    skillName = skillName
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

--- 抽个武将
---
--- 同getNCards，抽出来就没有了，所以记得放回去。
---@param n number @ 数量
---@param position string|nil @位置，top/bottom，默认top
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
    self:gameOver("")
  end
  return generals
end

--- 把武将牌塞回去（……）
---@param g string[] @ 武将名数组
---@param position string|nil @位置，top/bottom，默认bottom
---@return boolean @ 是否成功
function Room:returnToGeneralPile(g, position)
  position = position or "bottom"
  assert(position == "top" or position == "bottom")
  if position == "bottom" then
    table.insertTable(self.general_pile, g)
  elseif position == "top" then
    while #g > 0 do
      table.insert(self.general_pile, 1, table.remove(g))
    end
  end

  return true
end

--- 抽特定名字的武将（抽了就没了）
---@param name string @ 武将name，如找不到则查找truename，再找不到则返回nil
---@return string | nil @ 抽出的武将名
function Room:findGeneral(name)
  for i, g in ipairs(self.general_pile) do
    if g == name or Fk.generals[g].trueName == Fk.generals[name].trueName then
      return table.remove(self.general_pile, i)
    end
  end
  return nil
end

--- 自上而下抽符合特定情况的N个武将（抽了就没了）
---@param func fun(name: string):any @ 武将筛选函数
---@param n integer | nil @ 抽取数量，数量不足则直接抽干净
---@return string[] @ 武将组合，可能为空
function Room:findGenerals(func, n)
  n = n or 1
  local ret = {}
  local index = 1
  repeat
    if func(self.general_pile[index]) then
      table.insert(ret, table.remove(self.general_pile, index))
    else
      index = index + 1
    end
  until index >= #self.general_pile or #ret >= n
  return ret
end

--- 询问玩家选择一名武将。
---@param player ServerPlayer @ 询问目标
---@param generals string[] @ 可选武将
---@param n integer @ 可选数量，默认为1
---@param noConvert bool @ 可否变更，默认可
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

  return defaultChoice
end

--- 询问玩家若为神将、双势力需选择一个势力。
---@param players ServerPlayer[]|nil @ 询问目标
function Room:askForChooseKingdom(players)
  players = players or self.alive_players
  local specialKingdomPlayers = table.filter(players, function(p)
    return p.kingdom == "god" or Fk.generals[p.general].subkingdom
  end)

  if #specialKingdomPlayers > 0 then
    local choiceMap = {}
    for _, p in ipairs(specialKingdomPlayers) do
      local allKingdoms = {}
      if p.kingdom == "god" then
        allKingdoms = table.filter({"wei", "shu", "wu", "qun", "jin"}, function(k) return table.contains(Fk.kingdoms, k) end)
      else
        local curGeneral = Fk.generals[p.general]
        allKingdoms = { curGeneral.kingdom, curGeneral.subkingdom }
      end

      choiceMap[p.id] = allKingdoms

      local data = json.encode({ allKingdoms, allKingdoms, "AskForKingdom", "#ChooseInitialKingdom" })
      p.request_data = data
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
---@return integer @ 选择的卡牌id
function Room:askForCardChosen(chooser, target, flag, reason)
  local command = "AskForCardChosen"
  self:notifyMoveFocus(chooser, command)
  local data = {target.id, flag, reason}
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

--- 完全类似askForCardChosen，但是可以选择多张牌。
--- 相应的，返回的是id的数组而不是单个id。
---@param chooser ServerPlayer @ 要被询问的人
---@param target ServerPlayer @ 被选牌的人
---@param min integer @ 最小选牌数
---@param max integer @ 最大选牌数
---@param flag any @ 用"hej"三个字母的组合表示能选择哪些区域, h 手牌区, e - 装备区, j - 判定区
---@param reason string @ 原因，一般是技能名
---@return integer[] @ 选择的id
function Room:askForCardsChosen(chooser, target, min, max, flag, reason)
  if min == 1 and max == 1 then
    return { self:askForCardChosen(chooser, target, flag, reason) }
  end

  local command = "AskForCardsChosen"
  self:notifyMoveFocus(chooser, command)
  local data = {target.id, min, max, flag, reason}
  local result = self:doRequest(chooser, command, json.encode(data))

  local ret
  if result ~= "" then
    ret = json.decode(result)
  else
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
    if #handcards == 0 then return {} end
    ret = table.random(handcards, math.min(min, #handcards))
  end

  local new_ret = table.filter(ret, function(id) return id ~= -1 end)
  local hand_num = #ret - #new_ret
  if hand_num > 0 then
    table.insertTable(new_ret, table.random(target:getCardIds(Player.Hand), hand_num))
  end

  return new_ret
end

--- 谋askForCardsChosen，需使用Fk:addPoxiMethod定义好方法
---
--- 选卡规则和返回值啥的全部自己想办法解决，data填入所有卡的列表（类似ui.card_data）
---
--- 注意一定要返回一个表，毕竟本质上是选卡函数
---@param player ServerPlayer
---@param poxi_type string
---@param data any
---@return integer[]
function Room:askForPoxi(player, poxi_type, data)
  local poxi = Fk.poxi_methods[poxi_type]
  if not poxi then return {} end

  local command = "AskForPoxi"
  self:notifyMoveFocus(player, poxi_type)
  local result = self:doRequest(player, command, json.encode {
    type = poxi_type,
    data = data,
  })

  if result == "" then
    return poxi.default_choice(data)
  else
    return poxi.post_select(json.decode(result), data)
  end
end

--- 询问一名玩家从众多选项中选择一个。
---@param player ServerPlayer @ 要询问的玩家
---@param choices string[] @ 可选选项列表
---@param skill_name string|nil @ 技能名
---@param prompt string|nil @ 提示信息
---@param detailed bool @ 选项详细描述
---@param all_choices string[]|nil @ 所有选项（不可选变灰）
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
  if result == "" then result = choices[1] end
  return result
end

--- 询问玩家是否发动技能。
---@param player ServerPlayer @ 要询问的玩家
---@param skill_name string @ 技能名
---@param data any|nil @ 未使用
---@param prompt string|nil @ 提示信息
---@return boolean
function Room:askForSkillInvoke(player, skill_name, data, prompt)
  local command = "AskForSkillInvoke"
  self:notifyMoveFocus(player, skill_name)
  local invoked = false
  local result = self:doRequest(player, command, json.encode{ skill_name, prompt })
  if result ~= "" then invoked = true end
  return invoked
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

-- TODO: guanxing type
--- 询问玩家对若干牌进行观星。
---
--- 观星完成后，相关的牌会被置于牌堆顶或者牌堆底。所以这些cards最好不要来自牌堆，一般先用getNCards从牌堆拿出一些牌。
---@param player ServerPlayer @ 要询问的玩家
---@param cards integer[] @ 可以被观星的卡牌id列表
---@param top_limit integer[]|nil @ 置于牌堆顶的牌的限制(下限,上限)，不填写则不限
---@param bottom_limit integer[]|nil @ 置于牌堆底的牌的限制(下限,上限)，不填写则不限
---@param customNotify string|null @ 自定义读条操作提示
---param prompt string|null @ 观星框的标题(暂时雪藏)
---@param noPut bool @ 是否进行放置牌操作
---@param areaNames string[]|null @ 左侧提示信息
---@return table<"top"|"bottom", integer[]>
function Room:askForGuanxing(player, cards, top_limit, bottom_limit, customNotify, noPut, areaNames)
  -- 这一大堆都是来提前报错的
  top_limit = top_limit or Util.DummyTable
  bottom_limit = bottom_limit or Util.DummyTable
  if #top_limit > 0 then
    assert(top_limit[1] >= 0 and top_limit[2] >= 0, "limits error: The lower limit should be greater than 0")
    assert(top_limit[1] <= top_limit[2], "limits error: The upper limit should be less than the lower limit")
  end
  if #bottom_limit > 0 then
    assert(bottom_limit[1] >= 0 and bottom_limit[2] >= 0, "limits error: The lower limit should be greater than 0")
    assert(bottom_limit[1] <= bottom_limit[2], "limits error: The upper limit should be less than the lower limit")
  end
  if #top_limit > 0 and #bottom_limit > 0 then
    assert(#cards >= top_limit[1] + bottom_limit[1] and #cards <= top_limit[2] + bottom_limit[2], "limits Error: No enough space")
  end
  if areaNames then
    assert(#areaNames == 2, "areaNames error: Should have 2 elements")
  end
  local command = "AskForGuanxing"
  self:notifyMoveFocus(player, customNotify or command)
  local data = {
    prompt = "",
    cards = cards,
    min_top_cards = top_limit and top_limit[1] or 0,
    max_top_cards = top_limit and top_limit[2] or #cards,
    min_bottom_cards = bottom_limit and bottom_limit[1] or 0,
    max_bottom_cards = bottom_limit and bottom_limit[2] or #cards,
    top_area_name = areaNames and areaNames[1] or "Top",
    bottom_area_name = areaNames and areaNames[2] or "Bottom",
  }

  local result = self:doRequest(player, command, json.encode(data))
  local top, bottom
  if result ~= "" then
    local d = json.decode(result)
    if #top_limit > 0 and top_limit[2] == 0 then
      top = Util.DummyTable
      bottom = d[1]
    else
      top = d[1]
      bottom = d[2] or Util.DummyTable
    end
  else
    top = table.random(cards, top_limit and top_limit[2] or #cards) or Util.DummyTable
    bottom = table.shuffle(table.filter(cards, function(id) return not table.contains(top, id) end)) or Util.DummyTable
  end

  if not noPut then
    for i = #top, 1, -1 do
      table.insert(self.draw_pile, 1, top[i])
    end
    for i = #bottom, 1, -1 do
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
---@param piles table<cardIds, integer[]> @ 卡牌id列表的列表，也就是……几堆牌堆的集合
---@param piles_name string[] @ 牌堆名，必须一一对应，否则统一替换为“牌堆X”
---@param customNotify string|null @ 自定义读条操作提示
---@return table<cardIds, integer[]>
function Room:askForExchange(player, piles, piles_name, customNotify)
  local command = "AskForExchange"
  piles_name = piles_name or Util.DummyTable
  if #piles_name ~= #piles then
    piles_name = {}
    for i, _ in ipairs(piles) do
      table.insert(piles_name, "Pile" .. i)
    end
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
        self:doIndicate(player.id, targets)
        skill:onUse(self, {
          from = player.id,
          cards = selected_cards,
          tos = targets,
        })
      end)
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

        skill:beforeUse(player, use)

        self:useSkill(player, skill, Util.DummyFunc)

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
    for _, target in ipairs(targets) do
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
--- 询问玩家使用一张牌。
---@param player ServerPlayer @ 要询问的玩家
---@param card_name string|nil @ 使用牌的牌名，若pattern指定了则可随意写，它影响的是烧条的提示信息
---@param pattern string|nil @ 使用牌的规则，默认就是card_name的值
---@param prompt string|nil @ 提示信息
---@param cancelable bool @ 能否点取消
---@param extra_data integer|nil @ 额外信息
---@param event_data CardEffectEvent|nil @ 事件信息
---@return CardUseStruct | nil @ 返回关于本次使用牌的数据，以便后续处理
function Room:askForUseCard(player, card_name, pattern, prompt, cancelable, extra_data, event_data)
  if event_data and (event_data.disresponsive or table.contains(event_data.disresponsiveList or Util.DummyTable, player.id)) then
    return nil
  end

  if event_data and event_data.prohibitedCardNames and card_name then
    local splitedCardNames = card_name:split(",")
    splitedCardNames = table.filter(splitedCardNames, function(name)
      return not table.contains(event_data.prohibitedCardNames, name)
    end)

    if #splitedCardNames == 0 then
      return nil
    end

    card_name = table.concat(splitedCardNames, ",")
  end

  if extra_data then
    if extra_data.bypass_distances then
      player.room:setPlayerMark(player, MarkEnum.BypassDistancesLimit .. "-tmp", 1)
    end
    if extra_data.bypass_times ~= false then
      player.room:setPlayerMark(player, MarkEnum.BypassTimesLimit .. "-tmp", 1)
    end
  end
  local command = "AskForUseCard"
  self:notifyMoveFocus(player, card_name)
  cancelable = cancelable ~= false
  pattern = pattern or card_name
  prompt = prompt or ""

  local useData = {
    user = player,
    cardName = card_name,
    pattern = pattern,
    extraData = extra_data or Util.DummyTable,
    eventData = event_data
  }
  local use = nil
  self.logic:trigger(fk.AskForCardUse, player, useData)
  if type(useData.result) == "table" then
    useData = useData.result
    useData.extraUse = extra_data ~= nil
    self:useCard(useData)--请求用牌都在函数里执行用的事件，然后返回用的数据，如果用牌失败就不返回数据
    if useData.nullified then--卡牌无效的判定，如果是无效就只执行使用事件不执行生效事件
      use = false
    elseif useData.breakEvent ~= true then --卡牌终止判定，判定使用前是否被终止
      use = useData
    end
  end
  local data = { card_name, pattern, prompt, cancelable, extra_data or Util.DummyTable }
  while use == nil do
    Fk.currentResponsePattern = pattern
    local result = self:doRequest(player, command, json.encode(data))
    Fk.currentResponsePattern = nil
    if result ~= "" then
      result = self:handleUseCardReply(player, result)
      if result then
        result.extraUse = extra_data ~= nil
        self:useCard(result)
        if result.nullified then
          use = false
        elseif result.breakEvent ~= true then
          use = result
        end
      else
        break
      end
    else
      break
    end
  end
  player.room:setPlayerMark(player, MarkEnum.BypassDistancesLimit .. "-tmp", 0)
  player.room:setPlayerMark(player, MarkEnum.BypassTimesLimit .. "-tmp", 0)
  return use
end

--- 询问一名玩家打出一张牌。
---@param player ServerPlayer @ 要询问的玩家
---@param card_name string @ 牌名
---@param pattern string|nil @ 牌的规则
---@param prompt string|nil @ 提示信息
---@param cancelable bool @ 能否取消
---@param extra_data any|nil @ 额外数据
---@param effectData CardEffectEvent|nil @ 关联的卡牌生效流程
---@param retrial bool @ 改判打出
---@return Card | nil @ 打出的牌
function Room:askForResponse(player, card_name, pattern, prompt, cancelable, extra_data, effectData, retrial)
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
  }
  local response = nil
  self.logic:trigger(fk.AskForCardResponse, player, eventData)
  if eventData.result then
    eventData = {
      from = player.id,
      card = eventData.result,
      skipDrop = true,
      retrial = retrial,
      responseToEvent = effectData
    }
    eventData.extraResponse = extra_data ~= nil
    self:responseCard(eventData)
    if eventData.nullified then
      response = false
    elseif eventData.breakEvent ~= true then
      response = eventData
    end
  end
  local data = { card_name, pattern, prompt, cancelable, extra_data }
  while response == nil do
    Fk.currentResponsePattern = pattern
    local result = self:doRequest(player, command, json.encode(data))
    Fk.currentResponsePattern = nil
    if result ~= "" then
      result = self:handleUseCardReply(player, result)
      if result then
        result.skipDrop = true
        result.retrial = retrial
        result.responseToEvent = effectData
        result.extraResponse = extra_data ~= nil
        self:responseCard(result)
        if result.nullified then
          response = false
        elseif result.breakEvent ~= true then
          response = result
        end
      else
        break
      end
    else
      break
    end
  end
  return response
end

--- 同时询问多名玩家是否使用某一张牌。
---
--- 函数名字虽然是“询问无懈可击”，不过其实也可以给别的牌用就是了。
---@param players ServerPlayer[] @ 要询问的玩家列表
---@param card_name string @ 询问的牌名，默认为无懈
---@param pattern string @ 牌的规则
---@param prompt string|nil @ 提示信息
---@param cancelable bool @ 能否点取消
---@param extra_data any|nil @ 额外信息
---@return CardUseStruct | nil @ 最终决胜出的卡牌使用信息
function Room:askForNullification(players, card_name, pattern, prompt, cancelable, extra_data)

  local command = "AskForUseCard"
  card_name = card_name or "nullification"
  cancelable = (cancelable == nil) and true or cancelable
  extra_data = extra_data or Util.DummyTable
  prompt = prompt or ""
  pattern = pattern or card_name

  self:notifyMoveFocus(self.alive_players, card_name)
  self:doBroadcastNotify("WaitForNullification", "")

  local use = nil
  local data = { card_name, pattern, prompt, cancelable, extra_data or Util.DummyTable }
  while use == nil do
    Fk.currentResponsePattern = pattern
    local winner = self:doRaceRequest(command, players, json.encode(data))
    Fk.currentResponsePattern = nil
    if winner then
      local reply = self:handleUseCardReply(winner, winner.client_reply)
      if reply then
        local event = self.logic:getCurrentEvent():findParent(GameEvent.CardEffect, true).data[1]
        reply.responseToEvent = event
        reply.toCard = event.card
        reply.extraUse = extra_data ~= nil
        self:useCard(reply)
        if reply.nullified then
          use = false
        elseif reply.breakEvent ~= true then
          use = reply
        end
      else
        break
      end
    else
      break
    end
  end
  return use
end

-- AG(a.k.a. Amazing Grace) functions
-- Popup a box that contains many cards, then ask player to choose one

--- 询问玩家从AG中选择一张牌。
---@param player ServerPlayer @ 要询问的玩家
---@param id_list integer[] | Card[] @ 可选的卡牌列表
---@param cancelable bool @ 能否点取消
---@param reason string|nil @ 原因
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
---@param player ServerPlayer @ 要通知的玩家
---@param id_list integer[] | Card[] @ 要填充的卡牌
---@param disable_ids integer[] | Card[]|nil @ 未使用
function Room:fillAG(player, id_list, disable_ids)
  id_list = Card:getIdList(id_list)
  -- disable_ids = Card:getIdList(disable_ids)
  player:doNotify("FillAG", json.encode{ id_list, disable_ids })
end

--- 告诉一些玩家，AG中的牌被taker取走了。
---@param taker ServerPlayer @ 拿走牌的玩家
---@param id integer @ 被拿走的牌
---@param notify_list ServerPlayer[]|nil @ 要告知的玩家，默认为全员
function Room:takeAG(taker, id, notify_list)
  self:doBroadcastNotify("TakeAG", json.encode{ taker.id, id }, notify_list)
end

--- 关闭player那侧显示的AG。
---
--- 若不传参（即player为nil），那么关闭所有玩家的AG。
---@param player ServerPlayer|nil @ 要关闭AG的玩家
function Room:closeAG(player)
  if player then player:doNotify("CloseAG", "")
  else self:doBroadcastNotify("CloseAG", "") end
end

-- Show a qml dialog and return qml's ClientInstance.replyToServer
-- Do anything you like through this function

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

---@param player ServerPlayer @ 移动的操作
---@param targetOne ServerPlayer @ 移动的目标1玩家
---@param targetTwo ServerPlayer @ 移动的目标2玩家
---@param skillName string @ 技能名
---@param flag string|null @ 限定可移动的区域，值为nil（装备区和判定区）、‘e’或‘j’
---@param moveFrom ServerPlayer|null @ 是否只是目标1移动给目标2
---@param excludeIds CardId[]|null @ 本次不可移动的卡牌id
---@return table<"card"|"from"|"to">|null @ 选择的卡牌、起点玩家id和终点玩家id列表
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
---@param cancelable bool @ 是否可以取消选择
---@param flag string|null @ 限定可移动的区域，值为nil（装备区和判定区）、‘e’或‘j’
---@param no_indicate bool @ 是否不显示指示线
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

------------------------------------------------------------------------
-- 使用牌
------------------------------------------------------------------------

--- 根据卡牌使用数据，去实际使用这个卡牌。
---@param cardUseEvent CardUseStruct @ 使用数据
---@return boolean
function Room:useCard(cardUseEvent)
  return execGameEvent(GameEvent.UseCard, cardUseEvent)
end

---@param room Room
---@param cardUseEvent CardUseStruct
---@param aimEventCollaborators table<string, AimStruct[]>
---@return boolean
local onAim = function(room, cardUseEvent, aimEventCollaborators)
  local eventStages = { fk.TargetSpecifying, fk.TargetConfirming, fk.TargetSpecified, fk.TargetConfirmed }
  for _, stage in ipairs(eventStages) do
    if (not cardUseEvent.tos) or #cardUseEvent.tos == 0 then
      return false
    end

    room:sortPlayersByAction(cardUseEvent.tos, true)
    local aimGroup = AimGroup:initAimGroup(TargetGroup:getRealTargets(cardUseEvent.tos))

    local collaboratorsIndex = {}
    local firstTarget = true
    repeat
      local toId = AimGroup:getUndoneOrDoneTargets(aimGroup)[1]
      ---@type AimStruct
      local aimStruct
      local initialEvent = false
      collaboratorsIndex[toId] = collaboratorsIndex[toId] or 1

      if not aimEventCollaborators[toId] or collaboratorsIndex[toId] > #aimEventCollaborators[toId] then
        aimStruct = {
          from = cardUseEvent.from,
          card = cardUseEvent.card,
          to = toId,
          targetGroup = cardUseEvent.tos,
          nullifiedTargets = cardUseEvent.nullifiedTargets or {},
          tos = aimGroup,
          firstTarget = firstTarget,
          additionalDamage = cardUseEvent.additionalDamage,
          additionalRecover = cardUseEvent.additionalRecover,
          extra_data = cardUseEvent.extra_data,
        }

        local index = 1
        for _, targets in ipairs(cardUseEvent.tos) do
          if index > collaboratorsIndex[toId] then
            break
          end

          if #targets > 1 then
            for i = 2, #targets do
              aimStruct.subTargets = {}
              table.insert(aimStruct.subTargets, targets[i])
            end
          end
        end

        collaboratorsIndex[toId] = 1
        initialEvent = true
      else
        aimStruct = aimEventCollaborators[toId][collaboratorsIndex[toId]]
        aimStruct.from = cardUseEvent.from
        aimStruct.card = cardUseEvent.card
        aimStruct.tos = aimGroup
        aimStruct.targetGroup = cardUseEvent.tos
        aimStruct.nullifiedTargets = cardUseEvent.nullifiedTargets or {}
        aimStruct.firstTarget = firstTarget
        aimStruct.extra_data = cardUseEvent.extra_data
      end

      firstTarget = false

      if room.logic:trigger(stage, (stage == fk.TargetSpecifying or stage == fk.TargetSpecified) and room:getPlayerById(aimStruct.from) or room:getPlayerById(aimStruct.to), aimStruct) then
        return false
      end
      AimGroup:removeDeadTargets(room, aimStruct)

      local aimEventTargetGroup = aimStruct.targetGroup
      if aimEventTargetGroup then
        room:sortPlayersByAction(aimEventTargetGroup, true)
      end

      cardUseEvent.from = aimStruct.from
      cardUseEvent.tos = aimEventTargetGroup
      cardUseEvent.nullifiedTargets = aimStruct.nullifiedTargets
      cardUseEvent.extra_data = aimStruct.extra_data

      if #AimGroup:getAllTargets(aimStruct.tos) == 0 then
        return false
      end

      local cancelledTargets = AimGroup:getCancelledTargets(aimStruct.tos)
      if #cancelledTargets > 0 then
        for _, target in ipairs(cancelledTargets) do
          aimEventCollaborators[target] = {}
          collaboratorsIndex[target] = 1
        end
      end
      aimStruct.tos[AimGroup.Cancelled] = {}

      aimEventCollaborators[toId] = aimEventCollaborators[toId] or {}
      if room:getPlayerById(toId):isAlive() then
        if initialEvent then
          table.insert(aimEventCollaborators[toId], aimStruct)
        else
          aimEventCollaborators[toId][collaboratorsIndex[toId]] = aimStruct
        end

        collaboratorsIndex[toId] = collaboratorsIndex[toId] + 1
      end

      AimGroup:setTargetDone(aimStruct.tos, toId)
      aimGroup = aimStruct.tos
    until #AimGroup:getUndoneOrDoneTargets(aimGroup) == 0
  end

  return true
end

--- 对卡牌使用数据进行生效
---@param cardUseEvent CardUseStruct
function Room:doCardUseEffect(cardUseEvent)
  ---@type table<string, AimStruct>
  local aimEventCollaborators = {}
  if cardUseEvent.tos and not onAim(self, cardUseEvent, aimEventCollaborators) or cardUseEvent.nullified then --增加判定牌是否是无效
    return
  end

  local realCardIds = self:getSubcardsByRule(cardUseEvent.card, { Card.Processing })

  self.logic:trigger(fk.BeforeCardUseEffect, self:getPlayerById(cardUseEvent.from), cardUseEvent)
  -- If using Equip or Delayed trick, move them to the area and return
  if cardUseEvent.card.type == Card.TypeEquip then
    if #realCardIds == 0 then
      return
    end

    if self:getPlayerById(TargetGroup:getRealTargets(cardUseEvent.tos)[1]).dead then
      self:moveCards({
        ids = realCardIds,
        toArea = Card.DiscardPile,
        moveReason = fk.ReasonPutIntoDiscardPile,
      })
    else
      local target = TargetGroup:getRealTargets(cardUseEvent.tos)[1]
      local existingEquipId = self:getPlayerById(target):getEquipment(cardUseEvent.card.sub_type)
      if existingEquipId then
        self:moveCards(
          {
            ids = { existingEquipId },
            from = target,
            toArea = Card.DiscardPile,
            moveReason = fk.ReasonPutIntoDiscardPile,
          },
          {
            ids = realCardIds,
            to = target,
            toArea = Card.PlayerEquip,
            moveReason = fk.ReasonUse,
          }
        )
      else
        self:moveCards({
          ids = realCardIds,
          to = target,
          toArea = Card.PlayerEquip,
          moveReason = fk.ReasonUse,
        })
      end
    end

    return
  elseif cardUseEvent.card.sub_type == Card.SubtypeDelayedTrick then
    if #realCardIds == 0 then
      return
    end

    local target = TargetGroup:getRealTargets(cardUseEvent.tos)[1]
    if not self:getPlayerById(target).dead then
      local findSameCard = false
      for _, cardId in ipairs(self:getPlayerById(target):getCardIds(Player.Judge)) do
        if Fk:getCardById(cardId).trueName == cardUseEvent.card.trueName then
          findSameCard = true
        end
      end

      if not findSameCard then
        if cardUseEvent.card:isVirtual() then
          self:getPlayerById(target):addVirtualEquip(cardUseEvent.card)
        end

        self:moveCards({
          ids = realCardIds,
          to = target,
          toArea = Card.PlayerJudge,
          moveReason = fk.ReasonUse,
        })

        return
      end
    end

    self:moveCards({
      ids = realCardIds,
      toArea = Card.DiscardPile,
      moveReason = fk.ReasonPutIntoDiscardPile,
    })

    return
  end

  if not cardUseEvent.card.skill then
    return
  end

  ---@type CardEffectEvent
  local cardEffectEvent = {
    from = cardUseEvent.from,
    tos = cardUseEvent.tos,
    card = cardUseEvent.card,
    toCard = cardUseEvent.toCard,
    responseToEvent = cardUseEvent.responseToEvent,
    nullifiedTargets = cardUseEvent.nullifiedTargets,
    disresponsiveList = cardUseEvent.disresponsiveList,
    unoffsetableList = cardUseEvent.unoffsetableList,
    additionalDamage = cardUseEvent.additionalDamage,
    additionalRecover = cardUseEvent.additionalRecover,
    cardsResponded = cardUseEvent.cardsResponded,
    prohibitedCardNames = cardUseEvent.prohibitedCardNames,
    extra_data = cardUseEvent.extra_data,
  }

  -- If using card to other card (like jink or nullification), simply effect and return
  if cardUseEvent.toCard ~= nil then
    self:doCardEffect(cardEffectEvent)
    return
  end

  -- Else: do effect to all targets
  local collaboratorsIndex = {}
  for _, toId in ipairs(TargetGroup:getRealTargets(cardUseEvent.tos)) do
    if not table.contains(cardUseEvent.nullifiedTargets, toId) and self:getPlayerById(toId):isAlive() then
      if aimEventCollaborators[toId] then
        cardEffectEvent.to = toId
        collaboratorsIndex[toId] = collaboratorsIndex[toId] or 1
        local curAimEvent = aimEventCollaborators[toId][collaboratorsIndex[toId]]

        cardEffectEvent.subTargets = curAimEvent.subTargets
        cardEffectEvent.additionalDamage = curAimEvent.additionalDamage
        cardEffectEvent.additionalRecover = curAimEvent.additionalRecover

        if curAimEvent.disresponsiveList then
          cardEffectEvent.disresponsiveList = cardEffectEvent.disresponsiveList or {}

          for _, disresponsivePlayer in ipairs(curAimEvent.disresponsiveList) do
            if not table.contains(cardEffectEvent.disresponsiveList, disresponsivePlayer) then
              table.insert(cardEffectEvent.disresponsiveList, disresponsivePlayer)
            end
          end
        end

        if curAimEvent.unoffsetableList then
          cardEffectEvent.unoffsetableList = cardEffectEvent.unoffsetableList or {}

          for _, unoffsetablePlayer in ipairs(curAimEvent.unoffsetableList) do
            if not table.contains(cardEffectEvent.unoffsetableList, unoffsetablePlayer) then
              table.insert(cardEffectEvent.unoffsetableList, unoffsetablePlayer)
            end
          end
        end

        cardEffectEvent.disresponsive = curAimEvent.disresponsive
        cardEffectEvent.unoffsetable = curAimEvent.unoffsetable
        cardEffectEvent.fixedResponseTimes = curAimEvent.fixedResponseTimes
        cardEffectEvent.fixedAddTimesResponsors = curAimEvent.fixedAddTimesResponsors

        collaboratorsIndex[toId] = collaboratorsIndex[toId] + 1

        local curCardEffectEvent = table.simpleClone(cardEffectEvent)
        self:doCardEffect(curCardEffectEvent)

        if curCardEffectEvent.cardsResponded then
          cardUseEvent.cardsResponded = cardUseEvent.cardsResponded or {}
          for _, card in ipairs(curCardEffectEvent.cardsResponded) do
            table.insertIfNeed(cardUseEvent.cardsResponded, card)
          end
        end
      end
    end
  end
end

--- 对卡牌效果数据进行生效
---@param cardEffectEvent CardEffectEvent
function Room:doCardEffect(cardEffectEvent)
  return execGameEvent(GameEvent.CardEffect, cardEffectEvent)
end

---@param cardEffectEvent CardEffectEvent
function Room:handleCardEffect(event, cardEffectEvent)
  if event == fk.PreCardEffect then
    if cardEffectEvent.card.skill:aboutToEffect(self, cardEffectEvent) then return end
    if
      cardEffectEvent.card.trueName == "slash" and
      not (cardEffectEvent.unoffsetable or table.contains(cardEffectEvent.unoffsetableList or Util.DummyTable, cardEffectEvent.to))
    then
      local loopTimes = 1
      if cardEffectEvent.fixedResponseTimes then
        if type(cardEffectEvent.fixedResponseTimes) == "table" then
          loopTimes = cardEffectEvent.fixedResponseTimes["jink"] or 1
        elseif type(cardEffectEvent.fixedResponseTimes) == "number" then
          loopTimes = cardEffectEvent.fixedResponseTimes
        end
      end
      Fk.currentResponsePattern = "jink"

      for i = 1, loopTimes do
        local to = self:getPlayerById(cardEffectEvent.to)
        local prompt = nil
        if cardEffectEvent.from then
          if loopTimes > 1 then
            prompt = "#slash-jinks:" .. cardEffectEvent.from .. "::" .. loopTimes + 1 - i .. ":" .. loopTimes
          else
            prompt = "#slash-jink:" .. cardEffectEvent.from .. "::1"
          end
        end
        if self:askForUseCard(to, "jink", nil, prompt, true, nil, cardEffectEvent) then
          cardEffectEvent.isCancellOut = true
        else
          cardEffectEvent.isCancellOut = false
          break
        end
      end
    elseif
      cardEffectEvent.card.type == Card.TypeTrick and
      not (cardEffectEvent.disresponsive or cardEffectEvent.unoffsetable) and
      not table.contains(cardEffectEvent.prohibitedCardNames or Util.DummyTable, "nullification")
    then
      local players = {}
      Fk.currentResponsePattern = "nullification"
      for _, p in ipairs(self.alive_players) do
        local cards = p:getHandlyIds(true)
        for _, cid in ipairs(cards) do
          if
            Fk:getCardById(cid).trueName == "nullification" and
            not (
              table.contains(cardEffectEvent.disresponsiveList or Util.DummyTable, p.id) or
              table.contains(cardEffectEvent.unoffsetableList or Util.DummyTable, p.id)
            )
          then
            table.insert(players, p)
            break
          end
        end
        if not table.contains(players, p) then
          Self = p -- for enabledAtResponse
          for _, s in ipairs(table.connect(p.player_skills, p._fake_skills)) do
            if
              s.pattern and
              Exppattern:Parse("nullification"):matchExp(s.pattern) and
              not (s.enabledAtResponse and not s:enabledAtResponse(p)) and
              not (
                table.contains(cardEffectEvent.disresponsiveList or Util.DummyTable, p.id) or
                table.contains(cardEffectEvent.unoffsetableList or Util.DummyTable, p.id)
              )
            then
              table.insert(players, p)
              break
            end
          end
        end
      end

      local prompt = ""
      if cardEffectEvent.to then
        prompt = "#AskForNullification::" .. cardEffectEvent.to .. ":" .. cardEffectEvent.card.name
      elseif cardEffectEvent.from then
        prompt = "#AskForNullificationWithoutTo:" .. cardEffectEvent.from .. "::" .. cardEffectEvent.card.name
      end

      local extra_data
      if #TargetGroup:getRealTargets(cardEffectEvent.tos) > 1 then
        local parentUseEvent = self.logic:getCurrentEvent():findParent(GameEvent.UseCard)
        if parentUseEvent then
          extra_data = { useEventId = parentUseEvent.id, effectTo = cardEffectEvent.to }
        end
      end
      self:askForNullification(players, nil, nil, prompt, true, extra_data)
    end
    Fk.currentResponsePattern = nil
  elseif event == fk.CardEffecting then
    if cardEffectEvent.card.skill then
      execGameEvent(GameEvent.SkillEffect, function ()
        cardEffectEvent.card.skill:onEffect(self, cardEffectEvent)
      end, self:getPlayerById(cardEffectEvent.from), cardEffectEvent.card.skill)
    end
  end
end

--- 对“打出牌”进行处理
---@param cardResponseEvent CardResponseEvent
function Room:responseCard(cardResponseEvent)
  return execGameEvent(GameEvent.RespondCard, cardResponseEvent)
end

---@param card_name string @ 想要视为使用的牌名
---@param subcards integer[]|nil @ 子卡，可以留空或者直接nil
---@param from ServerPlayer @ 使用来源
---@param tos ServerPlayer | ServerPlayer[] @ 目标角色（列表）
---@param skillName string|nil @ 技能名
---@param extra bool @ 是否不计入次数
function Room:useVirtualCard(card_name, subcards, from, tos, skillName, extra)
  local card = Fk:cloneCard(card_name)
  card.skillName = skillName

  if from:prohibitUse(card) then return false end

  if tos.class then tos = { tos } end
  for i, p in ipairs(tos) do
    if from:isProhibited(p, card) then
      table.remove(tos, i)
    end
  end

  if #tos == 0 then return false end

  if subcards then card:addSubcards(Card:getIdList(subcards)) end

  local use = {} ---@type CardUseStruct
  use.from = from.id
  use.tos = table.map(tos, function(p) return { p.id } end)
  use.card = card
  use.extraUse = extra
  self:useCard(use)

  return true
end

------------------------------------------------------------------------
-- 移动牌
------------------------------------------------------------------------

--- 传入一系列移牌信息，去实际移动这些牌
---@vararg CardsMoveInfo
---@return boolean
function Room:moveCards(...)
  return execGameEvent(GameEvent.MoveCards, ...)
end

--- 让一名玩家获得一张牌
---@param player integer|ServerPlayer @ 要拿牌的玩家
---@param cid integer|Card @ 要拿到的卡牌
---@param unhide bool @ 是否明着拿
---@param reason CardMoveReason|nil @ 卡牌移动的原因
function Room:obtainCard(player, cid, unhide, reason)
  if type(cid) ~= "number" then
    assert(cid and cid:isInstanceOf(Card))
    cid = cid:isVirtual() and cid.subcards or {cid.id}
  else
    cid = {cid}
  end
  if #cid == 0 then return end

  if type(player) == "table" then
    player = player.id
  end

  self:moveCards({
    ids = cid,
    from = self.owner_map[cid[1]],
    to = player,
    toArea = Card.PlayerHand,
    moveReason = reason or fk.ReasonJustMove,
    proposer = player,
    moveVisible = unhide or false,
  })
end

--- 让玩家摸牌
---@param player ServerPlayer @ 摸牌的玩家
---@param num integer @ 摸牌数
---@param skillName string|nil @ 技能名
---@param fromPlace string|nil @ 摸牌的位置，"top" 或者 "bottom"
---@return integer[] @ 摸到的牌
function Room:drawCards(player, num, skillName, fromPlace)
  local drawData = {
    who = player,
    num = num,
    skillName = skillName,
    fromPlace = fromPlace,
  }
  if self.logic:trigger(fk.BeforeDrawCard, player, drawData) then
    self.logic:breakEvent(false)
  end

  num = drawData.num
  fromPlace = drawData.fromPlace

  local topCards = self:getNCards(num, fromPlace)
  self:moveCards({
    ids = topCards,
    to = player.id,
    toArea = Card.PlayerHand,
    moveReason = fk.ReasonDraw,
    proposer = player.id,
    skillName = skillName,
  })

  return { table.unpack(topCards) }
end

--- 将一张或多张牌移动到某处
---@param card Card | Card[] @ 要移动的牌
---@param to_place integer @ 移动的目标位置
---@param target ServerPlayer @ 移动的目标玩家
---@param reason integer|nil @ 移动时使用的移牌原因
---@param skill_name string|nil @ 技能名
---@param special_name string|nil @ 私人牌堆名
---@param visible bool @ 是否明置
---@param proposer integer | nil
function Room:moveCardTo(card, to_place, target, reason, skill_name, special_name, visible, proposer)
  reason = reason or fk.ReasonJustMove
  skill_name = skill_name or ""
  special_name = special_name or ""
  proposer = proposer or nil
  local ids = Card:getIdList(card)

  local to
  if table.contains(
    {Card.PlayerEquip, Card.PlayerHand,
      Card.PlayerJudge, Card.PlayerSpecial}, to_place) then
    to = target.id
  end

  local movesSplitedByOwner = {}
  for _, cardId in ipairs(ids) do
    local moveFound = table.find(movesSplitedByOwner, function(move)
      return move.from == self.owner_map[cardId]
    end)

    if moveFound then
      table.insert(moveFound.ids, cardId)
    else
      table.insert(movesSplitedByOwner, {
        ids = { cardId },
        from = self.owner_map[cardId],
        to = to,
        toArea = to_place,
        moveReason = reason,
        skillName = skill_name,
        specialName = special_name,
        moveVisible = visible,
        proposer = proposer,
      })
    end
  end

  self:moveCards(table.unpack(movesSplitedByOwner))
end

------------------------------------------------------------------------
-- 其他游戏事件
------------------------------------------------------------------------

-- 与体力值等有关的事件

--- 改变一名玩家的体力。
---@param player ServerPlayer @ 玩家
---@param num integer @ 变化量
---@param reason string|nil @ 原因
---@param skillName string|nil @ 技能名
---@param damageStruct DamageStruct|null @ 伤害数据
---@return boolean
function Room:changeHp(player, num, reason, skillName, damageStruct)
  return execGameEvent(GameEvent.ChangeHp, player, num, reason, skillName, damageStruct)
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

--- 令一名玩家失去体力。
---@param player ServerPlayer @ 玩家
---@param num integer @ 失去的数量
---@param skillName string|nil @ 技能名
---@return boolean
function Room:loseHp(player, num, skillName)
  return execGameEvent(GameEvent.LoseHp, player, num, skillName)
end

--- 改变一名玩家的体力上限。
---@param player ServerPlayer @ 玩家
---@param num integer @ 变化量
---@return boolean
function Room:changeMaxHp(player, num)
  return execGameEvent(GameEvent.ChangeMaxHp, player, num)
end

--- 根据伤害数据造成伤害。
---@param damageStruct DamageStruct
---@return boolean
function Room:damage(damageStruct)
  return execGameEvent(GameEvent.Damage, damageStruct)
end

--- 根据回复数据回复体力。
---@param recoverStruct RecoverStruct
---@return boolean
function Room:recover(recoverStruct)
  return execGameEvent(GameEvent.Recover, recoverStruct)
end

--- 根据濒死数据让人进入濒死。
---@param dyingStruct DyingStruct
function Room:enterDying(dyingStruct)
  return execGameEvent(GameEvent.Dying, dyingStruct)
end

--- 根据死亡数据杀死角色。
---@param deathStruct DeathStruct
function Room:killPlayer(deathStruct)
  return execGameEvent(GameEvent.Death, deathStruct)
end

-- 与失去/获得技能有关的事件

--- 令一名玩家获得/失去技能。
---
--- skill_names 是字符串数组或者用管道符号(|)分割的字符串。
---
--- 每个skill_name都是要获得的技能的名。如果在skill_name前面加上"-"，那就是失去技能。
---@param player ServerPlayer @ 玩家
---@param skill_names string[] | string @ 要获得/失去的技能
---@param source_skill string | Skill | null @ 源技能
---@param no_trigger bool @ 是否不触发相关时机
function Room:handleAddLoseSkills(player, skill_names, source_skill, sendlog, no_trigger)
  if type(skill_names) == "string" then
    skill_names = skill_names:split("|")
  end

  if sendlog == nil then sendlog = true end

  if #skill_names == 0 then return end
  local losts = {}  ---@type boolean[]
  local triggers = {} ---@type Skill[]
  for _, skill in ipairs(skill_names) do
    if string.sub(skill, 1, 1) == "-" then
      local actual_skill = string.sub(skill, 2, #skill)
      if player:hasSkill(actual_skill, true, true) then
        local lost_skills = player:loseSkill(actual_skill, source_skill)
        for _, s in ipairs(lost_skills) do
          self:doBroadcastNotify("LoseSkill", json.encode{
            player.id,
            s.name
          })

          if sendlog and s.visible then
            self:sendLog{
              type = "#LoseSkill",
              from = player.id,
              arg = s.name
            }
          end

          table.insert(losts, true)
          table.insert(triggers, s)
        end
      end
    else
      local sk = Fk.skills[skill]
      if sk and not player:hasSkill(sk, true, true) then
        local got_skills = player:addSkill(sk)

        for _, s in ipairs(got_skills) do
          -- TODO: limit skill mark

          self:doBroadcastNotify("AddSkill", json.encode{
            player.id,
            s.name
          })

          if sendlog and s.visible then
            self:sendLog{
              type = "#AcquireSkill",
              from = player.id,
              arg = s.name
            }
          end

          table.insert(losts, false)
          table.insert(triggers, s)
        end
      end
    end
  end

  if (not no_trigger) and #triggers > 0 then
    for i = 1, #triggers do
      local event = losts[i] and fk.EventLoseSkill or fk.EventAcquireSkill
      self.logic:trigger(event, player, triggers[i])
    end
  end
end

-- 判定

--- 根据判定数据进行判定。判定的结果直接保存在这个数据中。
---@param data JudgeStruct
function Room:judge(data)
  return execGameEvent(GameEvent.Judge, data)
end

--- 改判。
---@param card Card @ 改判的牌
---@param player ServerPlayer @ 改判的玩家
---@param judge JudgeStruct @ 要被改判的判定数据
---@param skillName string|nil @ 技能名
---@param exchange bool @ 是否要替换原有判定牌（即类似鬼道那样）
function Room:retrial(card, player, judge, skillName, exchange)
  if not card then return end
  local triggerResponded = self.owner_map[card:getEffectiveId()] == player
  local isHandcard = (triggerResponded and self:getCardArea(card:getEffectiveId()) == Card.PlayerHand)

  local oldJudge = judge.card
  judge.card = Fk:getCardById(card:getEffectiveId())
  local rebyre = judge.retrial_by_response
  judge.retrial_by_response = player

  local resp = {} ---@type CardResponseEvent
  resp.from = player.id
  resp.card = card

  if triggerResponded then
    self.logic:trigger(fk.PreCardRespond, player, resp)
  end

  local move1 = {} ---@type CardsMoveInfo
  move1.ids = { card:getEffectiveId() }
  move1.from = player.id
  move1.toArea = Card.Processing
  move1.moveReason = fk.ReasonResonpse
  move1.skillName = skillName

  local move2 = {} ---@type CardsMoveInfo
  move2.ids = { oldJudge:getEffectiveId() }
  move2.toArea = exchange and Card.PlayerHand or Card.DiscardPile
  move2.moveReason = fk.ReasonJustMove
  move2.to = exchange and player.id or nil

  self:sendLog{
    type = "#ChangedJudge",
    from = player.id,
    to = { judge.who.id },
    card = { card:getEffectiveId() },
    arg = skillName,
  }

  self:moveCards(move1)
  self:moveCards(move2)

  if triggerResponded then
    self.logic:trigger(fk.CardRespondFinished, player, resp)
  end
end

--- 弃置一名角色的牌。
---@param card_ids integer[] @ 被弃掉的牌
---@param skillName string|nil @ 技能名
---@param who ServerPlayer @ 被弃牌的人
---@param thrower ServerPlayer|nil @ 弃别人牌的人
function Room:throwCard(card_ids, skillName, who, thrower)
  if type(card_ids) == "number" then
    card_ids = {card_ids}
  end
  skillName = skillName or ""
  thrower = thrower or who
  self:moveCards({
    ids = card_ids,
    from = who.id,
    toArea = Card.DiscardPile,
    moveReason = fk.ReasonDiscard,
    proposer = thrower.id,
    skillName = skillName
  })
end

--- 重铸一名角色的牌。
---@param card_ids integer[] @ 被重铸的牌
---@param who ServerPlayer @ 重铸的角色
---@param skillName string|nil @ 技能名，默认为“重铸”
function Room:recastCard(card_ids, who, skillName)
  if type(card_ids) == "number" then
    card_ids = {card_ids}
  end
  skillName = skillName or "recast"
  self:moveCards({
    ids = card_ids,
    from = who.id,
    toArea = Card.DiscardPile,
    skillName = skillName,
    moveReason = fk.ReasonPutIntoDiscardPile,
    proposer = who.id
  })
  self:sendLog{
    type = skillName == "recast" and "#Recast" or "#RecastBySkill",
    from = who.id,
    card = card_ids,
    arg = skillName,
  }
  self:drawCards(who, #card_ids, skillName)
end

--- 根据拼点信息开始拼点。
---@param pindianData PindianStruct
function Room:pindian(pindianData)
  return execGameEvent(GameEvent.Pindian, pindianData)
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
  if #self.draw_pile + #self.discard_pile == 0 then
    return
  end

  table.insertTable(self.draw_pile, self.discard_pile)
  for _, id in ipairs(self.discard_pile) do
    self:setCardArea(id, Card.DrawPile, nil)
  end
  self.discard_pile = {}
  table.shuffle(self.draw_pile)

  self.logic:trigger(fk.AfterDrawPileShuffle, nil, {})
end

--- 使用技能。先增加技能发动次数，再执行相应的函数。
---@param player ServerPlayer @ 发动技能的玩家
---@param skill Skill @ 发动的技能
---@param effect_cb fun() @ 实际要调用的函数
function Room:useSkill(player, skill, effect_cb)
  player:revealBySkillName(skill.name)
  if not skill.mute then
    if skill.attached_equip then
      local equip = Fk:cloneCard(skill.attached_equip)
      local pkgPath = "./packages/" .. equip.package.extensionName
      local soundName = pkgPath .. "/audio/card/" .. equip.name
      self:broadcastPlaySound(soundName)
      self:setEmotion(player, pkgPath .. "/image/anim/" .. equip.name)
    else
      player:broadcastSkillInvoke(skill.name)
      self:notifySkillInvoked(player, skill.name)
    end
  end

  if skill:isSwitchSkill() then
    local switchSkillName = skill.switchSkillName
    self:setPlayerMark(
      player,
      MarkEnum.SwithSkillPreName .. switchSkillName,
      player:getSwitchSkillState(switchSkillName, true)
    )
  end

  if effect_cb then
    return execGameEvent(GameEvent.SkillEffect, effect_cb, player, skill)
  end
end

---@param player ServerPlayer
---@param sendLog bool
function Room:revivePlayer(player, sendLog)
  if not player.dead then return end
  self:setPlayerProperty(player, "dead", false)
  player._splayer:setDied(false)
  self:setPlayerProperty(player, "dying", false)
  self:setPlayerProperty(player, "hp", player.maxHp)
  table.insertIfNeed(self.alive_players, player)

  sendLog = (sendLog == nil) and true or sendLog
  if sendLog then
    self:sendLog { type = "#Revive", from = player.id }
  end
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

  self.logic:trigger(fk.GameFinished, nil, winner)
  self.game_started = false
  self.game_finished = true

  for _, p in ipairs(self.players) do
    self:broadcastProperty(p, "role")
  end
  self:doBroadcastNotify("GameOver", winner)

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

---@param card Card
---@param fromAreas CardArea[]|null
---@return integer[]
function Room:getSubcardsByRule(card, fromAreas)
  if card:isVirtual() and #card.subcards == 0 then
    return {}
  end

  local cardIds = {}
  fromAreas = fromAreas or Util.DummyTable
  for _, cardId in ipairs(card:isVirtual() and card.subcards or { card.id }) do
    if #fromAreas == 0 or table.contains(fromAreas, self:getCardArea(cardId)) then
      table.insert(cardIds, cardId)
    end
  end

  return cardIds
end

---@param pattern string
---@param num number|null
---@param fromPile string|null @ 查找的来源区域，值为drawPile|discardPile|allPiles
---@return cardId[]
function Room:getCardsFromPileByRule(pattern, num, fromPile)
  num = num or 1
  local pileToSearch = self.draw_pile
  if fromPile == "discardPile" then
    pileToSearch = self.discard_pile
  elseif fromPile == "allPiles" then
    pileToSearch = table.simpleClone(self.draw_pile)
    table.insertTable(pileToSearch, self.discard_pile)
  end

  if #pileToSearch == 0 then
    return {}
  end

  local cardPack = {}
  if num < 3 then
    for i = 1, num do
      local randomIndex = math.random(1, #pileToSearch)
      local curIndex = randomIndex
      repeat
        local curCardId = pileToSearch[curIndex]
        if Fk:getCardById(curCardId):matchPattern(pattern) and not table.contains(cardPack, curCardId) then
          table.insert(cardPack, pileToSearch[curIndex])
          break
        end

        curIndex = curIndex + 1
        if curIndex > #pileToSearch then
          curIndex = 1
        end
      until curIndex == randomIndex

      if #cardPack == 0 then
        break
      end
    end
  else
    local matchedIds = {}
    for _, id in ipairs(pileToSearch) do
      if Fk:getCardById(id):matchPattern(pattern) then
        table.insert(matchedIds, id)
      end
    end

    local loopTimes = math.min(num, #matchedIds)
    for i = 1, loopTimes do
      local randomCardId = matchedIds[math.random(1, #matchedIds)]
      table.insert(cardPack, randomCardId)
      table.removeOne(matchedIds, randomCardId)
    end
  end

  return cardPack
end

---@param flag string|null
---@param players ServerPlayer[]|null
---@param excludeIds CardId[]|null
---@return PlayerId[] @ 可能为空
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
---@param suit Suit|nil @ 花色
---@param number integer|nil @ 点数
---@return Card
function Room:printCard(name, suit, number)
  local cd = Fk:cloneCard(name, suit, number)
  Fk:_addPrintedCard(cd)
  table.insert(self.void, cd.id)
  self:setCardArea(cd.id, Card.Void, nil)
  self:doBroadcastNotify("PrintCard", json.encode{ name, suit, number })
  return cd
end

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
  })

  table.insertTable(player.sealedSlots, slotsToSeal)
  self:broadcastProperty(player, "sealedSlots")

  self.logic:trigger(fk.AreaAborted, player, { slots = slotsSealed })
end

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
    self.logic:trigger(fk.AreaResumed, player, { slots = slotsToResume })
  end
end

return Room
