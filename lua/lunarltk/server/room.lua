-- SPDX-License-Identifier: GPL-3.0-or-later

--- Room是fk游戏逻辑运行的主要场所，同时也提供了许多API函数供编写技能使用。
---
--- 一个房间中只有一个Room实例，保存在RoomInstance全局变量中。
---@class Room : AbstractRoom, ServerRoomBase, GameEventWrappers, CompatAskFor
---@field public extra_turn_list table @ 待执行的额外回合表
---@field public general_pile string[] @ 武将牌堆，这是可用武将名的数组
---@field public skill_costs table<string, any> @ 存放skill.cost_data用
---@field public card_marks table<integer, any> @ 存放card.mark之用
---@field public current_cost_skill TriggerSkill? @ AI用
local Room = AbstractRoom:subclass("Room")

-- 此为勾式的手写泛型. 本意是extends AbstractRoom<ServerPlayer>
---@class Room
---@field public players ServerPlayer[]
---@field public alive_players ServerPlayer[] @ 所有存活玩家的数组
---@field public observers ServerPlayer[]
---@field public current ServerPlayer
---@field public getPlayerById fun(self: AbstractRoom, id: integer): ServerPlayer
---@field public getPlayerBySeat fun(self: AbstractRoom, seat: integer): ServerPlayer
---@field public setCurrent fun(self: AbstractRoom, p: ServerPlayer)
---@field public getCurrent fun(self: AbstractRoom): ServerPlayer
---@field public logic GameLogic

local ServerRoomBase = Fk.Base.ServerRoomBase
Room:include(ServerRoomBase)

local GameEventWrappers = require "lunarltk.server.events"
local CompatAskFor = require "compat.askfor"
Room:include(GameEventWrappers)
Room:include(CompatAskFor)

-- 唉，兼容个锤子牢函数
-- GameLogic:include(dofile "lua/compat/gamelogic.lua")

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

---@param _room fk.Room
function Room:initialize(_room)
  AbstractRoom.initialize(self)
  ServerRoomBase.initialize(self, _room)

  self.serverplayer_klass = ServerPlayer
  self.logic_klass = GameLogic

  self.extra_turn_list = {}
  self.general_pile = {}

  self.disabled_packs = self:getSettings('disabledPack')
  if not Fk.game_modes[self:getSettings('gameMode')] then
    self.settings.gameMode = "aaa_role_mode"
  end

  table.insertTable(self.disabled_packs, Fk.game_mode_disabled[self:getSettings('gameMode')])
  self.disabled_generals = self:getSettings('disabledGenerals')

  self:addCallback("prelight", self.handlePrelight)
  self:addCallback("updatemini", self.handleUpdateMini)
  self:addCallback("changeskin", self.handleChangeSkin)
end

function Room:handlePrelight(id, data)
  local p = self:getPlayerById(id)
  if p then
    p:prelightSkill(data[3], data[4] == "true")
  end
end

function Room:handleUpdateMini(id, reqlist)
  local player = self:getPlayerById(id)
  local data = player.mini_game_data
  if not data then return end
  local game = Fk.mini_games[data.type]
  if not (game and game.update_func) then return end
  local dat = table.simpleClone(reqlist)
  table.remove(dat, 1)
  table.remove(dat, 1)
  game.update_func(player, dat)
end

function Room:handleChangeSkin(id, data)
  self:doBroadcastNotify("ChangeSkin", data)
end

-- 构造武将牌堆。同名武将只留下一张
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

function Room:run()
  self:makeGeneralPile()
  ServerRoomBase.run(self)
end

function Room:__tostring()
  return string.format("<Room #%d>", self.id)
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

---@param players ServerPlayer[]
---@param player? ServerPlayer @ 以该角色为起点（缺省值为当前回合角色）
function Room:sortByAction(players, player)
  table.sort(players, function(prev, next)
    return prev.seat < next.seat
  end)

  local org_player = player or self.current

  if org_player and table.find(players, function(p)
    return p.seat >= org_player.seat
  end) then
    while players[1].seat < org_player.seat do
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

--- 清除一名角色手牌中的某种标记
---@param player ServerPlayer @ 要清理标记的角色
---@param name string @ 要清理的标记名
function Room:clearHandMark(player, name)
  local card = nil
  for _, id in ipairs(player:getCardIds("h")) do
    card = Fk:getCardById(id)
    if card:getMark(name) > 0 then
      self:setCardMark(card, name, 0)
    end
  end
end

--- 将一张卡牌的```mark```标记设置为```value```，并通知所有客户端更新。
--- 
--- 通用的mark名称及后缀参见```mark_enum.lua```。
---@param card Card @ 更新标记的牌
---@param mark string @ 标记的名称
---@param value any @ 设置的值，可以是数字、字符串、表、键值表等
function Room:setCardMark(card, mark, value)
  card:setMark(mark, value)
  if not card:isVirtual() then
    self:doBroadcastNotify("SetCardMark", {
      card.id,
      mark,
      value
    })
  end
end

--- 将一张卡牌的```mark```标记增加```count```个，并通知所有客户端更新。
---@param card Card @ 增加标记的牌
---@param mark string @ 标记名称
---@param count? integer @ 增加的数量，默认为1
function Room:addCardMark(card, mark, count)
  count = count or 1
  local num = card:getMark(mark)
  num = num or 0
  self:setCardMark(card, mark, math.max(num + count, 0))
end

--- 将一名玩家的```mark```标记减少```count```个，并通知所有客户端更新。
---@param card Card @ 减少标记的牌
---@param mark string @ 标记名称
---@param count? integer @ 减少的数量，默认为1
function Room:removeCardMark(card, mark, count)
  count = count or 1
  local num = card:getMark(mark)
  num = num or 0
  self:setCardMark(card, mark, math.max(num - count, 0))
end

--- 设置房间的当前行动者
---@param player ServerPlayer
function Room:setCurrent(player)
  AbstractRoom.setCurrent(self, player)
  -- rawset(self, "current", player)
  self:doBroadcastNotify("SetCurrent", { player and player.id or nil })
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
  if table.find(skills, function (s) return Fk.skills[s]:hasTag(Skill.Hidden) end) then
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

function Room:serialize(player)
  local o = ServerRoomBase.serialize(self, player)
  o.round_count = self:getBanner("RoundCount") or 0
  return o
end

------------------------------------------------------------------------
-- 网络通信有关
------------------------------------------------------------------------

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

  local tempSk = Fk.skills[command]
  if tempSk and #players == 1 then
    local p = players[1]
    if p:isFakeSkill(tempSk) then
      command = ""
      players = self.alive_players
    end
  end

  ServerRoomBase.notifyMoveFocus(self, players, command, timeout)
end

-- 为一些牌设置脚注
---@param ids integer[] @ 要设置虚拟牌名的牌的id列表
---@param log LogMessage @ Log的实际内容
---@param virtual? boolean @ 是否为虚拟牌
function Room:sendFootnote(ids, log, virtual)
  self:doBroadcastNotify("SetCardFootnote", { ids, log, not not virtual })
end

--- 为一些牌设置虚拟转化牌名（仅影响桌面上的牌，处理区/弃牌堆/虚空区）
---@param ids integer[] @ 要设置虚拟牌名的牌的id列表
---@param name string @ 虚拟牌名
---@param virtual? boolean @ 是否为虚拟牌
function Room:sendCardVirtName(ids, name, virtual)
  self:doBroadcastNotify("SetCardVirtName", { ids, name, not not virtual })
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
  self:doBroadcastNotify("LogEvent", data, players)
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
---@param tos? integer[] | ServerPlayer[] @ 技能目标，填空则不声明
function Room:notifySkillInvoked(player, skill_name, skill_type, tos)
  local bigAnim = false
  local skill = Fk.skills[skill_name]
  if not skill then skill_type = "" else
    if not (skill.mute or skill.is_delay_effect) and skill:hasTag(Skill.Limited) then
      bigAnim = true -- 优先大招特效
    end
    if not skill_type then
      skill_type = skill.anim_type
    end
  end

  if skill_type == "big" then bigAnim = true end

  if tos and #tos > 0 then
    tos = table.map(tos, function (to)
      if type(to) == "table" then
        return to.id
      else
        return to
      end
    end)
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
    skill_name = skill:getSkeleton().name
    self:doAnimate("InvokeUltSkill", {
      name = skill_name,
      player = player.id,
      deputy = Fk.generals[player.deputyGeneral] ~= nil and table.contains(Fk.generals[player.deputyGeneral]:getSkillNameList(true), skill_name),
    })
    self:delay(2000)
  end
end

--- 播放从source指到targets的指示线效果。
---@param source integer | ServerPlayer @ 指示线开始的那个玩家
---@param targets integer[] | ServerPlayer[] @ 指示线目标玩家的列表
function Room:doIndicate(source, targets)
  if type(source) == "table" then
    source = source.id
  end
  local target_group = {}
  for _, p in ipairs(targets) do
    if type(p) == "table" then
      table.insert(target_group, { p.id })
    else
      table.insert(target_group, { p })
    end
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
---@field skill_name string @ 请求发动的技能名
---@field cancelable? boolean @ 是否可以点取消
---@field no_indicate? boolean @ 是否不显示指示线
---@field extra_data? table @ 额外信息（使用```skillName```指定烧条时的显示技能名）
---@field skip? boolean @ 是否跳过实际执行流程

--- 询问player是否要发动一个主动技。
---
--- 如果发动的话，那么会执行一下技能的onUse函数，然后返回选择的牌和目标等。
---@param player ServerPlayer @ 询问目标
---@param params AskToUseActiveSkillParams @ 各种变量
---@return boolean, { cards: integer[], targets: ServerPlayer[], interaction: any }? @ 返回第一个值为是否成功发动，第二值为技能选牌、目标等数据
function Room:askToUseActiveSkill(player, params)
  params.prompt = params.prompt or ""
  params.cancelable = (params.cancelable == nil) and true or params.cancelable
  params.no_indicate = (params.no_indicate == nil) and true or params.no_indicate
  params.extra_data = params.extra_data or Util.DummyTable
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

  local use_spec = {
    from = player,
    cards = selected_cards,
    tos = table.map(targets, Util.Id2PlayerMapper),
    interaction = interaction
  }
  local use_data = skill:handleCostData(player, use_spec, params.extra_data)

  if not params.skip then
    skill:onUse(self, use_data)
  end

  return true, {
    cards = use_data.cards,
    targets = use_data.tos,
    interaction = interaction
  }
end

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
    targets = table.map(params.targets, Util.IdMapper),
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

  local canChosenCards = player:getCardIds(params.include_equip and "he" or "h")
  if type(expand_pile) == "string" then
    table.insertTable(canChosenCards, player:getPile(expand_pile))
  elseif type(expand_pile) == "table" then
    table.insertTable(canChosenCards, expand_pile)
  end
  canChosenCards = table.filter(canChosenCards, function(cid)
    return Exppattern:Parse(params.pattern):match(Fk:getCardById(cid))
  end)
  if not params.cancelable and #canChosenCards < minNum then
    minNum = #canChosenCards -- 防止牌不够的情况无法按确定和取消
  end

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
    chosenCards = table.random(canChosenCards, minNum)
  end

  return chosenCards
end

---@class ViewCardsParams: AskToSkillInvokeParams
---@field cards integer[] @ 待观看卡牌

--- 询问玩家观看一些牌（只有确定可用）
---@param player ServerPlayer @ 要询问的玩家
---@param params ViewCardsParams @ 参数列表
function Room:viewCards(player, params)
  self:askToViewCardsAndChoice(player, {
    cards = params.cards,
    skill_name = params.skill_name,
    prompt = params.prompt,
  })
end

---@class AskToViewCardsAndChoiceParams: ViewCardsParams
---@field choices? string[] @ 可选选项列表，默认值为“确定”

--- 询问玩家观看一些牌并做出选项，但是选项有额外的点亮标准
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToViewCardsAndChoiceParams @ 参数列表
---@return string
function Room:askToViewCardsAndChoice(player, params)
  local _, result = self:askToChooseCardsAndChoice(player, {
    cards = params.cards,
    choices = params.choices,
    skill_name = params.skill_name,
    prompt = params.prompt or "$ViewCards",
    min_num = 0,
    max_num = 0
  })
  return result
end

---@class AskToChooseCardsAndChoiceParams: AskToViewCardsAndChoiceParams
---@field cards integer[] @ 待选卡牌
---@field default_choice? string @ 始终可用的分支，会置于最左侧且始终可用，若为空则choice的第一项始终可用。当需要```filter_skel_name```审查时**建议填入**
---@field choices? string[] @ 可选选项列表，默认值为“确定”，受```filter_skel_name```的审查
---@field filter_skel_name? string @ 带```extra.choiceFilter(cards: integer[], choice: string, extra_data: table?): boolean?```的技能**骨架**名，无则所有选项均可用
---@field cancel_choices? string[] @ 可选选项列表（不选择牌时的选项），默认为空
---@field all_cards? integer[]  @ 会显示的所有卡牌
---@field min_num? integer  @ 最小选牌数（默认为1）
---@field max_num? integer  @ 最大选牌数（默认为1）
---@field extra_data? table @ 额外信息，因技能而异了

--- 询问玩家选择牌和选项，但是选项有额外的点亮标准
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToChooseCardsAndChoiceParams @ 参数列表
---@return integer[], string
function Room:askToChooseCardsAndChoice(player, params)
  local cards, choices, skillname, prompt, cancel_choices, min, max, all_cards =
    params.cards, params.choices, params.skill_name, params.prompt,
    params.cancel_choices, params.min_num, params.max_num, params.all_cards
  choices = choices or {"OK"}
  local default_choice = params.default_choice or choices[1]
  if default_choice ~= nil and not table.contains(choices, default_choice) then
    table.insert(choices, 1, default_choice)
  end
  cancel_choices = cancel_choices or {}
  min = min or 1
  max = max or 1
  assert(min <= max, "limits error: The upper limit should be less than the lower limit")
  assert(#cards >= min or #cancel_choices > 0, "limits Error: No enough cards")
  assert(#choices > 0 or #cancel_choices > 0, "should have choice to choose")
  local data = {
    cards = all_cards or cards,
    choices = choices,
    prompt = prompt,
    cancel_choices = cancel_choices,
    min = min,
    max = max,
    filter_skel = params.filter_skel_name,
    disabled = all_cards and table.filter(all_cards, function (id)
      return not table.contains(cards, id)
    end) or {},
    extra_data = params.extra_data or {}
  }
  local command = "AskForCardsAndChoice"
  local req = Request:new(player, command)
  req.focus_text = skillname
  req:setData(player, data)
  local result = req:getResult(player)
  if result ~= "" then
    return result.cards, result.choice
  end
  return table.random(cards, min), default_choice
end

---@class AskToChooseCardsAndPlayersParams: AskToChoosePlayersParams
---@field min_card_num integer @ 选卡牌最小值
---@field max_card_num integer @ 选卡牌最大值
---@field equal? boolean @ 是否要求牌数和目标数相等，默认否
---@field pattern? string @ 选牌规则，默认为"."
---@field expand_pile? string|integer[] @ 可选私人牌堆名称，或额外可选牌
---@field will_throw? boolean @ 选卡牌须能弃置

--- 询问玩家选择X张牌和Y名角色。
---
--- 返回两个值，第一个是选择目标列表，第二个是选择的牌id列表，第三个是否按了确定
--- 
--- 默认可取消
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToChooseCardsAndPlayersParams @ 各种变量
---@return ServerPlayer[], integer[], boolean @ 第一个是选择目标列表，第二个是选择的牌id列表，第三个是否按了确定
function Room:askToChooseCardsAndPlayers(player, params)
  local maxTargetNum, minTargetNum, maxCardNum, minCardNum = params.max_num, params.min_num, params.max_card_num, params.min_card_num
  params.cancelable = (params.cancelable == nil) and true or params.cancelable
  params.no_indicate = params.no_indicate or false
  params.pattern = params.pattern or "."
  params.equal = params.equal or false
  local expand_pile = params.expand_pile or (params.extra_data and params.extra_data.expand_pile)

  local pcards = player:getCardIds("he")
  if type(expand_pile) == "string" then
    table.insertTable(pcards, player:getPile(expand_pile))
  elseif type(expand_pile) == "table" then
    table.insertTable(pcards, expand_pile)
  end
  local exp = Exppattern:Parse(params.pattern)
  pcards = table.filter(pcards, function(cid)
    return exp:match(Fk:getCardById(cid)) and not (params.will_throw and player:prohibitDiscard(cid))
  end)
  if #pcards < minCardNum and not params.cancelable then return {}, {}, false end

  local data = {
    targets = table.map(params.targets, Util.IdMapper),
    max_t_num = maxTargetNum,
    min_t_num = minTargetNum,
    max_c_num = maxCardNum,
    min_c_num = minCardNum,
    equal = params.equal,
    pattern = params.pattern,
    skillName = params.skill_name,
    targetTipName = params.target_tip_name,
    extra_data = params.extra_data,
    expand_pile = params.expand_pile or (params.extra_data and params.extra_data.expand_pile),
    will_throw = params.will_throw,
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
---@field targets? ServerPlayer[] @ 可分配的目标角色，默认为所有存活角色
---@field cards? integer[] @ 要分配的卡牌。默认拥有的所有牌
---@field expand_pile? string|integer[] @ 可选私人牌堆名称，或额外可选牌
---@field single_max? integer|table @ 限制每人能获得的最大牌数。输入整数或(以角色id为键以整数为值)的表
---@field skip? boolean @ 是否跳过移动。默认不跳过
---@field moveMark? table|string @ 移动后自动赋予标记，格式：{标记名(支持-inarea后缀，移出值代表区域后清除), 值}

--- 询问将卡牌分配给任意角色。
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToYijiParams @ 各种变量
---@return table<integer, integer[]> @ 返回一个表，键为角色id，值为分配给其的牌id数组
function Room:askToYiji(player, params)
  local targets = params.targets or self:getAlivePlayers(false)
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
    expand_pile = expand_pile,
    skillName = skillName,
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
      local to = dat.targets[1].id
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
    self:doYiji(list, player, skillName, params.moveMark)
  end

  return list
end

---@class AskToChooseGeneralParams
---@field generals string[] @ 可选武将
---@field n? integer @ 可选数量，默认为1
---@field no_convert? boolean @ 可否同名替换，默认可
---@field rule? string @ 选将规则名（使用```Fk:addChooseGeneralRule```定义），默认为askForGeneralsChosen
---@field extra_data? table @ 额外信息，键值表。预留：```skill_name```技能名
---@field heg? boolean @ 是否应用国战ui（提示珠联璧合和主副将调整阴阳鱼）。默认选将规则为heg_general_choose

--- 询问玩家选择一名武将。
---@param player ServerPlayer @ 询问目标
---@param params AskToChooseGeneralParams @ 各种变量
---@return string|string[] @ 选择的武将，一个是string，多个是string[]
function Room:askToChooseGeneral(player, params)
  local command = "AskForGeneral"
  local rule_type = params.rule or "askForGeneralsChosen"
  local rule = Fk.choose_general_rule[rule_type]
  if not rule then return {} end

  local n, generals = params.n or 1, params.generals
  if #generals == n then return n == 1 and generals[1] or generals end
  local extra_data = params.extra_data or {}
  extra_data.n = extra_data.n or n
  local defaultChoice = rule.default_choice(generals, extra_data)

  local req = Request:new(player, command)
  req.timeout = self:getSettings('generalTimeout')
  local data = {
    generals,
    n,
    params.no_convert or false,
    params.heg or false,
    rule_type,
    extra_data,
  }
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
    return (Fk.generals[p.general].subkingdom ~= nil) or #Fk:getKingdomMap(p.kingdom) > 0
  end)

  if #specialKingdomPlayers > 0 then
    local req = Request:new(specialKingdomPlayers, "AskForChoice")
    req.focus_text = "AskForKingdom"
    req.receive_decode = false
    req.focus_players = self.alive_players
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

---@class AskToChooseCardParams: AskToSkillInvokeParams
---@field target ServerPlayer @ 被选牌的人
---@field flag string | {card_data: [string, integer[]][]} @ 用"hej"三个字母的组合表示能选择哪些区域, h 手牌区, e - 装备区, j - 判定区
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

--- 谋askForCardsChosen，需使用```Fk:addPoxiMethod```定义好方法
---
--- 选卡规则和返回值啥的全部自己想办法解决，```data```填入所有卡的列表（类似```ui.card_data```）
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
---@field pattern? string @ 只针对可见牌的选牌规则

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
    pattern = params.pattern
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

  local poxiParams = { ---@type AskToPoxiParams
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

  local hide = false -- 是否隐藏读条，用于国战同时机技能选择
  if params.skill_name == "trigger" then
    for _, s in ipairs(params.choices) do
      local skill_name = s
      if skill_name:startsWith("#skill_muti_trigger") then
        local strSplited = skill_name:split(":")
        skill_name = strSplited[#strSplited - 1]
      end
      if player:isFakeSkill(skill_name) then
        hide = true
        break
      end
    end
  end
  local req = Request:new(player, command)
  req.focus_text = hide and "" or params.skill_name
  req.focus_players = hide and self.alive_players or nil
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

---@class askToJointChoiceParams
---@field players ServerPlayer[] @ 被询问的玩家
---@field choices string[] @ 可选选项列表
---@field skill_name? string @ 技能名
---@field prompt? string @ 提示信息
---@field send_log? boolean @ 是否发Log，默认否

--- 同时询问多名玩家从众多选项中选择一个（要求所有玩家选项相同，不同的请自行构造request）
---@param player ServerPlayer @ 发起者
---@param params askToJointChoiceParams @ 各种变量
---@return table<Player, string> @ 返回键值表，键为Player、值为选项
function Room:askToJointChoice(player, params)
  local skillName = params.skill_name or "AskForChoice"
  local prompt = params.prompt or "AskForChoice"
  local players, choices = params.players, params.choices
  local sendLog = params.send_log or false

  local req = Request:new(players, "AskForChoice")
  req.focus_text = skillName
  req.receive_decode = false
  local data = {
    choices,
    choices,  --如果all_choices和choices不一样应该自行构造request
    skillName,
    prompt,
  }
  for _, p in ipairs(players) do
    req:setData(p, data)
    req:setDefaultReply(p, table.random(choices))  --默认项为随机选项
  end
  req:ask()
  if sendLog then
    for _, p in ipairs(players) do
      p.room:sendLog{
        type = "#Choice",
        from = p.id,
        arg = req:getResult(p),
        toast = true,
      }
    end
  end
  local ret = {}
  for _, p in ipairs(players) do
    ret[p] = req:getResult(p)
  end
  return ret
end

---@class askToJointCardsParams
---@field players ServerPlayer[] @ 被询问的玩家
---@field min_num integer @ 最小值
---@field max_num integer @ 最大值
---@field include_equip? boolean @ 能不能选装备
---@field skill_name? string @ 技能名
---@field cancelable? boolean @ 能否点取消
---@field pattern? string @ 选牌规则
---@field prompt? string @ 提示信息
---@field expand_pile? string @ 可选私人牌堆名称
---@field will_throw? boolean @ 是否是弃牌，默认否（在这个流程中牌不会被弃掉，仅用作禁止弃置技判断）

--- 同时询问多名玩家选择一些牌（要求所有玩家选牌规则相同，不同的请自行构造request）
---@param player ServerPlayer @ 发起者
---@param params askToJointCardsParams @ 各种变量
---@return table<ServerPlayer, integer[]> @ 返回键值表，键为Player、值为选择的牌id列表
function Room:askToJointCards(player, params)
  local skill_name = params.skill_name or "AskForCardChosen"
  local cancelable = (params.cancelable == nil) and true or params.cancelable
  local pattern = params.pattern or "."
  local players, maxNum, minNum = params.players, params.max_num, params.min_num
  local include_equip = params.include_equip or false
  local expand_pile = params.expand_pile or nil
  local will_throw = params.will_throw or false
  local prompt = params.prompt or ("#AskForCard:::" .. maxNum .. ":" .. minNum)

  local toAsk = {}
  local ret = {}
  if cancelable then
    toAsk = players
  else
    for _, p in ipairs(players) do
      local cards = {}
      if include_equip then
        table.insertTable(cards, p:getCardIds("he"))
      else
        table.insertTable(cards, p:getCardIds("h"))
      end
      if expand_pile then
        if type(expand_pile) == "string" then
          table.insertTableIfNeed(cards, p:getPile(expand_pile))
        elseif type(expand_pile) == "table" then
          table.insertTableIfNeed(cards, expand_pile)
        end
      end
      local exp = Exppattern:Parse(pattern)
      cards = table.filter(cards, function(cid)
        return exp:match(Fk:getCardById(cid)) and not (will_throw and p:prohibitDiscard(cid))
      end)
      if #cards > minNum then
        table.insert(toAsk, p)
      end
      ret[p] = table.random(cards, minNum)
    end
    if #toAsk == 0 then
      return ret
    end
  end

  local req = Request:new(toAsk, "AskForUseActiveSkill")
  req.focus_text = skill_name
  req.focus_players = players
  local data = {
    will_throw and "discard_skill" or "choose_cards_skill",
    prompt,
    cancelable,
    {
      num = maxNum,
      min_num = minNum,
      include_equip = include_equip,
      skillName = skill_name,
      pattern = pattern,
      expand_pile = expand_pile,
    },
  }

  for _, p in ipairs(toAsk) do
    req:setData(p, data)
    req:setDefaultReply(p, ret[p] or {})
  end
  req:ask()
  for _, p in ipairs(toAsk) do
    local ids = {}
    local result = req:getResult(p)
    if result ~= "" then
      if result.card then
        ids = result.card.subcards
      else
        ids = result
      end
    end
    ret[p] = ids
  end
  return ret
end



---@class AskToSkillInvokeParams
---@field skill_name string @ 询问技能名（烧条时显示的技能名）
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
  req.focus_text = params.skill_name
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

---@class AskToGuanxingParams : AskToSkillInvokeParams
---@field cards integer[] @ 可以被观星的卡牌id列表
---@field top_limit? integer[] @ 置于牌堆顶的牌的限制(下限,上限)，不填写则不限
---@field bottom_limit? integer[] @ 置于牌堆底的牌的限制(下限,上限)，不填写则不限
---@field skill_name? string @ 烧条时显示的技能名
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
  local cards, top_limit, bottom_limit, customNotify, noPut = params.cards, params.top_limit, params.bottom_limit, params.skill_name, params.skip
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
  local piles, customNotify = params.piles, params.skill_name
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
      table.insert(self.general_pile, math.random(math.max(#self.general_pile - 1, 1)),
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

---@class handleUseCardParams: AskToUseCardParams
---@field is_response? boolean

--- 将从Request获得的数据转化为UseCardData，或执行主动技的onUse部分
--- 一般DIY用不到的内部函数
---@param player ServerPlayer
---@param data any
---@param params? handleUseCardParams
---@return UseCardDataSpec|string? @ 返回字符串则取消使用，若返回技能名，在当前询问中禁用此技能
function Room:handleUseCardReply(player, data, params)
  local card = data.card
  local targets = data.targets or {}
  local extra_data = (params or {}).extra_data or Util.DummyTable
  if type(card) == "table" then
    local card_data = card
    local skill = Fk.skills[card_data.skill]
    local selected_cards = card_data.subcards
    if skill.interaction then skill.interaction.data = data.interaction_data end
    if skill:isInstanceOf(ActiveSkill) then
      ---@cast skill ActiveSkill

      local use_spec = {
        from = player,
        cards = selected_cards,
        tos = table.map(targets, Util.Id2PlayerMapper),
        interaction_data = data.interaction_data,
      }
      local use_data = skill:handleCostData(player, use_spec, extra_data)

      self:useSkill(player, skill, function()
        skill:onUse(self, use_data)
      end, use_data)
      return nil
    elseif skill:isInstanceOf(ViewAsSkill) then
      ---@cast skill ViewAsSkill
      --Self = player
      local useResult
      local c = skill:viewAs(player, selected_cards)

      local use_spec = {
        from = player,
        cards = selected_cards,
        tos = table.map(targets, Util.Id2PlayerMapper),
        interaction_data = data.interaction_data,
      }
      local use_data = skill:handleCostData(player, use_spec, extra_data)

      self:useSkill(player, skill, function()
        useResult = skill:onUse(self, use_data, c, params) or ""
        if type(useResult) == "table" then
          if params == nil then
            player.room:useCard(useResult)
            skill:afterUse(player, useResult)
            useResult = nil
          else
            useResult.attachedSkillAndUser = { skillName = skill.name, user = player.id, muteCard = skill.mute_card }
          end
        end
      end, use_data)
      return useResult
    end
  else
    if data.special_skill then
      local skill = Fk.skills[data.special_skill]
      assert(skill:isInstanceOf(ActiveSkill))
      ---@cast skill ActiveSkill
      local use_spec = {
        from = player,
        cards = { card },
        tos = table.map(targets, Util.Id2PlayerMapper),
      }
      local use_data = skill:handleCostData(player, use_spec, extra_data)
      skill:onUse(self, use_data)
      return nil
    end
    local use = {}
    use.from = player
    use.tos = table.map(targets or Util.DummyTable, Util.Id2PlayerMapper)
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
  if extra_data.not_passive == nil then extra_data.not_passive = true end
  local pattern, skillName, prompt, cancelable, skipUse = params.pattern, params.skill_name, params.prompt, params.cancelable, params.skip

  local pile = params.expand_pile or extra_data.expand_pile
  local cards = player:getCardIds("h")
  if type(pile) == "string" then
    table.insertTable(cards, player:getPile(pile))
  elseif type(pile) == "table" then
    table.insertTable(cards, pile)
  end
  if pile and extra_data.expand_pile == nil then
    extra_data.expand_pile = pile
  end

  local cardIds = {}
  for _, cid in ipairs(cards) do
    local card = Fk:getCardById(cid)
    if Exppattern:Parse(pattern):match(card) then
      if #card:getAvailableTargets(player, extra_data) > 0 or
        (card.is_passive and not extra_data.not_passive and not player:prohibitUse(card)) then
        table.insert(cardIds, cid)
      end
    end
  end

  extra_data.skillName = skillName
  if #cardIds == 0 and not cancelable then return end
  extra_data.cardIds = cardIds
  local _, dat = self:askToUseActiveSkill(player, {
    skill_name = "userealcard_skill",
    prompt = prompt,
    cancelable = cancelable,
    extra_data = extra_data,
  })
  if (not cancelable) and (not dat) then
    for _, cid in ipairs(cardIds) do
      local card = Fk:getCardById(cid)
      local temp = card:getDefaultTarget(player, extra_data)
      if #temp > 0 or (card.is_passive and not extra_data.not_passive and not player:prohibitUse(card)) then
        dat = {targets = temp, cards = {cid}}
        break
      end
    end
  end
  if not dat then return end
  local card = Fk:getCardById(dat.cards[1])
  if card == nil then return end
  local use = {
    from = player,
    tos = #dat.targets > 0 and dat.targets or card:getDefaultTarget(player, extra_data),
    card = card,
    extraUse = extra_data.extraUse,
  }
  if not skipUse then
    self:useCard(use)
  end
  return use
end

---@class askToUseVirtualCardParams: AskToSkillInvokeParams
---@field name string|string[] @ 可以选择的虚拟卡名，可以多个
---@field subcards? integer[] @ 虚拟牌的子牌，默认空
---@field card_filter? { cards: integer[]?, n: integer|integer[]?, pattern: string?, fake_subcards: boolean? } @选牌规则，优先级低于```subcards```，可选参数：```n```（牌数，填数字表示此只能此数量，填{a, b}表示至少为a至多为b）```pattern```（选牌规则）```cards```（可选牌的范围）```fake_subcards```（是否不计为实际子卡）
---@field prompt? string @ 询问提示信息。默认为：请视为使用xx
---@field extra_data? UseExtraData|table @ 额外信息，因技能而异了
---@field cancelable? boolean @ 是否可以取消。默认可以取消
---@field skip? boolean @ 是否跳过使用。默认不跳过

--- 询问玩家使用一张虚拟卡，或从几种牌名中选择一种视为使用
---@param player ServerPlayer @ 要询问的玩家
---@param params askToUseVirtualCardParams @ 各种变量
---@return UseCardDataSpec? @ 返回卡牌使用框架。取消使用则返回空
function Room:askToUseVirtualCard(player, params)
  local extra_data = params.extra_data and table.simpleClone(params.extra_data) or {}
  params.name = params.name
  if type(params.name) == "table" then
    extra_data.namebox = true
  else
    params.name = {params.name}
  end
  params.subcards = params.subcards or {}
  params.skill_name = params.skill_name or ""
  params.prompt = params.prompt
  if params.prompt == nil then
    if #params.name == 1 then
      params.prompt = ("#AskForUseVirtualCard:::"..params.skill_name..":"..params.name[1])
    else
      params.prompt = ("#AskForUseVirtualCards:::"..params.skill_name)
    end
  end
  if (params.cancelable == nil) then params.cancelable = true end
  params.card_filter = params.card_filter or {}
  params.card_filter.n = params.card_filter.n or {0, 0}
  if type(params.card_filter.n) == "number" then
    params.card_filter.n = { params.card_filter.n, params.card_filter.n }
  end
  params.card_filter.pattern = params.card_filter.pattern or "."
  params.card_filter.cards = params.card_filter.cards or table.connect(player:getCardIds("he"), player:getHandlyIds(false))

  if extra_data.bypass_times == nil then extra_data.bypass_times = true end
  if extra_data.extraUse == nil then extra_data.extraUse = true end
  local all_names, subcards, skillName, prompt, cancelable, skipUse = params.name, params.subcards, params.skill_name, params.prompt, params.cancelable, params.skip
  extra_data.skillName = skillName
  local names = table.filter(all_names, function (name)
    local card = Fk:cloneCard(name)
    card:addSubcards(subcards)
    card.skillName = skillName
    return #card:getAvailableTargets(player, extra_data) > 0
  end)
  if #names == 0 then return end
  if not cancelable then
    local card
    for _, n in ipairs(names) do
      card = Fk:cloneCard(n)
      if #subcards > 0 then
        card:addSubcards(subcards)
      elseif params.card_filter.n[1] > 0 then
        local cards = table.filter(params.card_filter.cards, function (id)
          return Fk:getCardById(id):matchPattern(params.card_filter.pattern)
        end)
        if #cards < params.card_filter.n[1] then
          return nil
        end
        if params.card_filter.fake_subcards then
          card:addFakeSubcards(table.random(cards, params.card_filter.n[1]))
        else
          card:addSubcards(table.random(cards, params.card_filter.n[1]))
        end
      end
      card.skillName = skillName
      if #card:getDefaultTarget(player, extra_data) > 0 then
        break
      end
      if n == names[#names] then
        return nil
      end
    end
  end

  extra_data.choices = names
  extra_data.all_choices = all_names
  extra_data.subcards = subcards
  extra_data.card_filter = params.card_filter
  local _, dat = self:askToUseActiveSkill(player, {
    skill_name = "virtual_viewas",
    prompt = prompt,
    cancelable = cancelable,
    extra_data = extra_data,
  })
  local card, tos
  if dat then
    card = Fk:cloneCard(#all_names == 1 and all_names[1] or dat.interaction)
    if #subcards > 0 then
      card:addSubcards(subcards)
    elseif #dat.cards > 0 then
      if params.card_filter.fake_subcards then
        card:addFakeSubcards(dat.cards)
      else
        card:addSubcards(dat.cards)
      end
    end
    card.skillName = skillName
    tos = #dat.targets > 0 and dat.targets or card:getDefaultTarget(player, extra_data)
  else
    if cancelable then return end
    for _, n in ipairs(names) do
      card = Fk:cloneCard(n)
      if #subcards > 0 then
        card:addSubcards(subcards)
      elseif params.card_filter.n[1] > 0 then
        local cards = table.filter(params.card_filter.cards, function (id)
          return Fk:getCardById(id):matchPattern(params.card_filter.pattern)
        end)
        if #cards < params.card_filter.n[1] then
          return nil
        end
        if params.card_filter.fake_subcards then
          card:addFakeSubcards(table.random(cards, params.card_filter.n[1]))
        else
          card:addSubcards(table.random(cards, params.card_filter.n[1]))
        end
      end
      card.skillName = skillName
      tos = card:getDefaultTarget(player, extra_data)
    end
  end
  if not tos or #tos == 0 then return end
  local use = {
    from = player,
    tos = tos,
    card = card,
    extraUse = extra_data.extraUse,
  }
  if not skipUse then
    self:useCard(use)
  end
  return use
end

---@class askToPlayCardParams: AskToSkillInvokeParams
---@field cards? integer[] @ 可以选择的卡牌，默认包括手牌和“如手牌”
---@field pattern? string @ 选卡规则，与可用卡牌取交集
---@field extra_data? UseExtraData|table @ 额外信息，因技能而异了
---@field skip? boolean @ 是否跳过使用。默认不跳过
---@field cancelable? boolean @ 是否可以取消。目前不支持无法取消

--- 询问玩家（如在空闲时间点一般）使用一张实体牌，支持转化技。
---@param player ServerPlayer @ 要询问的玩家
---@param params askToPlayCardParams @ 各种变量
---@return UseCardDataSpec? @ 返回关于本次使用牌的数据，以便后续处理
function Room:askToPlayCard(player, params)
  local cards = params.cards or player:getHandlyIds()
  local pattern = params.pattern or "."
  local skillName =  params.skill_name or "#AskForPlayCard"
  local prompt =  params.prompt or ("#AskForPlayCard:::"..skillName)
  local extra_data = params.extra_data or {}

  local useables = {} -- 可用牌名
  local useableTrues = {} -- 可用牌真名
  for _, name in ipairs(Fk.all_card_names) do
    local card = Fk:cloneCard(name)
    card:setVSPattern(nil, player, ".")
    if not player:prohibitUse(card) and card.skill:canUse(player, card, extra_data) then
      table.insertIfNeed(useables, card.name)
      table.insertIfNeed(useableTrues, card.trueName)
    end
  end
  local cardIds = player:getCardIds("e")
  for _, cid in ipairs(cards) do
    local card = Fk:getCardById(cid)
    if not (Exppattern:Parse(pattern):match(card) and
      card.skill:canUse(player, card, extra_data) and
      not player:prohibitUse(card)) then
      table.insert(cardIds, cid)
    end
  end
  local strid = table.concat(cardIds, ",")
  local useable_pattern = table.concat(useableTrues, ",") ..
    "|.|.|.|" .. table.concat(useables, ",") ..
    "|.|" .. (strid == "" and "." or "^(" .. strid .. ")")
  extra_data = extra_data or {}
  local use = self:askToUseCard(player, {
    skill_name = skillName,
    pattern = useable_pattern,
    prompt = prompt,
    cancelable = true,
    extra_data = extra_data,
  })
  if not use then return end
  if extra_data.extraUse then
    use.extraUse = true
  end
  if not params.skip then
    self:useCard(use)
  end
  return use
end

---@class askToNumberParams: AskToSkillInvokeParams
---@field prompt? string @ 询问提示信息。默认为：请选择一个数字
---@field min integer @ 最小值
---@field max integer @ 最大值
---@field cancelable? boolean @ 是否可以取消。默认不可取消

--- 询问玩家选择一个数字
---@param player ServerPlayer @ 要询问的玩家
---@param params askToNumberParams @ 各种变量
---@return integer? @ 返回选择的数字。取消则返回空
function Room:askToNumber(player, params)
  params.skill_name = params.skill_name or ""
  params.prompt = params.prompt
  if params.prompt == nil then
    params.prompt = ("#AskForNumber:::"..params.skill_name)
  end
  local _, dat = self:askToUseActiveSkill(player, {
    skill_name = "spin_skill",
    prompt = params.prompt,
    cancelable = params.cancelable,
    extra_data = {
      min = params.min,
      max = params.max,
      skillName = params.skill_name,
    },
  })
  if dat then
    return dat.interaction
  else
    if params.cancelable then
      return nil
    else
      return math.random(params.min, params.max)
    end
  end
end

---@class AskToUseCardParams: AskToSkillInvokeParams
---@field pattern string @ 使用牌的规则
---@field cancelable? boolean @ 是否可以取消。默认可以取消
---@field extra_data? UseExtraData|table @ 额外信息，因技能而异了
---@field event_data? CardEffectData @ 事件信息，如借刀事件之于询问杀

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
  local skillName, prompt, cancelable, event_data = params.skill_name, params.prompt, params.cancelable, params.event_data
  if event_data and event_data:isDisresponsive(player) then
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

  local askForUseCardData = { ---@type AskForCardData
    user = player,
    skillName = skillName,
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
      local data = {skillName, pattern, prompt, cancelable, extra_data, disabledSkillNames}

      Fk.currentResponsePattern = pattern
      self.logic:trigger(fk.HandleAskForPlayCard, player, askForUseCardData, true)

      local req = Request:new(player, command)
      req.focus_text = skillName or ""
      req.timeout = self:getBanner("Timeout") and self:getBanner("Timeout")[tostring(player.id)] or self.timeout
      req:setData(player, data)
      local result = req:getResult(player)

      askForUseCardData.afterRequest = true
      askForUseCardData.overtimes = req.overtimes
      self.logic:trigger(fk.HandleAskForPlayCard, player, askForUseCardData, true)
      Fk.currentResponsePattern = nil

      if result ~= "" then
        useResult = self:handleUseCardReply(player, result, {
          skill_name = skillName,
          prompt = prompt,
          pattern = pattern,
          cancelable = cancelable,
          extra_data = extra_data,
          event_data = event_data,
        })

        if type(useResult) == "string" and useResult ~= "" then
          table.insertIfNeed(disabledSkillNames, useResult)
        end
      end
    until type(useResult) ~= "string"

    askForUseCardData.result = useResult
  end

  if type(askForUseCardData.result) == "table" then
    if event_data then
      local resultData = askForUseCardData.result
      if not resultData.responseToEvent then
        resultData.responseToEvent = event_data
      end

      if not resultData.toCard and resultData.card and resultData.card.is_passive then
        resultData.toCard = event_data.card
      end
    end
  end

  self.logic:trigger(fk.AfterAskForCardUse, player, askForUseCardData)
  return useResult
end

--- 询问一名玩家打出一张牌。
---@param player ServerPlayer @ 要询问的玩家
---@param params AskToUseCardParams @ 各种变量
---@return RespondCardDataSpec? @ 打出的事件
function Room:askToResponse(player, params)
  params.cancelable = (params.cancelable == nil) and true or params.cancelable
  local extra_data = params.extra_data and table.simpleClone(params.extra_data) or {}
  params.prompt = params.prompt or ""
  local skillName, pattern, prompt, cancelable, event_data =
    params.skill_name, params.pattern, params.prompt,
    params.cancelable, params.event_data
  if event_data and event_data:isDisresponsive(player) then
    return nil
  end

  local command = "AskForResponseCard"

  local askForUseCardData = { ---@type AskForCardData
    user = player,
    skillName = skillName,
    pattern = pattern,
    extraData = extra_data,
    eventData = event_data,
  }
  self.logic:trigger(fk.AskForCardResponse, player, askForUseCardData)

  local responseResult
  if askForUseCardData.result then
    if type(askForUseCardData.result) == "table" then
      responseResult = askForUseCardData.result
    else
      askForUseCardData.result = nil
    end
  else
    local disabledSkillNames = {}

    repeat
      responseResult = nil
      local data = {skillName, pattern, prompt, cancelable, extra_data, disabledSkillNames}

      Fk.currentResponsePattern = pattern
      askForUseCardData.isResponse = true
      self.logic:trigger(fk.HandleAskForPlayCard, player, askForUseCardData, true)

      local req = Request:new(player, command)
      req.focus_text = skillName or ""
      req.timeout = self:getBanner("Timeout") and self:getBanner("Timeout")[tostring(player.id)] or self.timeout
      req:setData(player, data)
      local result = req:getResult(player)

      askForUseCardData.afterRequest = true
      askForUseCardData.overtimes = req.overtimes
      self.logic:trigger(fk.HandleAskForPlayCard, player, askForUseCardData, true)
      Fk.currentResponsePattern = nil

      if result ~= "" then
        responseResult = self:handleUseCardReply(player, result, {
          skill_name = skillName,
          prompt = prompt,
          pattern = pattern,
          cancelable = cancelable,
          extra_data = extra_data,
          event_data = event_data,
          is_response = true
        })

        if type(responseResult) == "string" and responseResult ~= "" then
          table.insertIfNeed(disabledSkillNames, responseResult)
        end
      end
    until type(responseResult) ~= "string"

    askForUseCardData.result = responseResult
  end

  if type(askForUseCardData.result) == "table" then
    askForUseCardData.result.tos = nil
    if event_data then
      if not askForUseCardData.result.responseToEvent then
        askForUseCardData.result.responseToEvent = event_data
      end
    end
  end

  self.logic:trigger(fk.AfterAskForCardResponse, player, askForUseCardData)
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
    eventData.overtimes = req.overtimes
    self.logic:trigger(fk.HandleAskForPlayCard, nil, eventData, true)

    if winner then
      local result = req:getResult(winner)
      useResult = self:handleUseCardReply(winner, result, {
        skill_name = card_name,
        prompt = prompt,
        pattern = pattern,
        cancelable = cancelable,
        extra_data = extra_data,
        event_data = event_data,
      })

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
    player:doNotify("FillAG", { id_list, disable_ids })
  end
end

--- 告诉一些玩家，AG中的牌被taker取走了。
---@param taker ServerPlayer @ 拿走牌的玩家
---@param id integer @ 被拿走的牌
---@param notify_list? ServerPlayer[] @ 要告知的玩家，默认为全员
function Room:takeAG(taker, id, notify_list)
  self:doBroadcastNotify("TakeAG", { taker.id, id }, notify_list)
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
        p:doNotify("FillAG", { newRecord[2], newRecord[3] })
      end
      for cid, pid in pairs(newRecord[4]) do
        self:doBroadcastNotify("TakeAG", { pid, tonumber(cid) }, players)
      end
    end
  end
end

---@class AskToMiniGameParams
---@field skill_name string @ 烧条时显示的技能名
---@field game_type string @ 小游戏框关键词
---@field data_table table<integer, any> @ 以每个playerID为键的数据数组
---@field timeout? integer @ 烧条时间，单位为秒。默认使用房间的timeout

-- TODO: 重构request机制，不然这个还得手动拿client_reply
---@param players ServerPlayer[] @ 需要参与这个框的角色
---@param params AskToMiniGameParams @ 各种变量
---@return Request
function Room:askToMiniGame(players, params)
  local command = "MiniGame"
  local game = Fk.mini_games[params.game_type]
  if #players == 0 or not game then return end

  local req = Request:new(players, command)
  req.focus_text = params.skill_name
  req.receive_decode = false -- 和customDialog同理
  req.timeout = params.timeout or self.timeout

  for _, p in ipairs(players) do
    local data = params.data_table[p.id]
    p.mini_game_data = { type = params.game_type, data = data }
    req:setData(p, p.mini_game_data)
    req:setDefaultReply(p, game.default_choice and game.default_choice(p, data))
  end

  req:ask()

  for _, p in ipairs(players) do
    p.mini_game_data = nil
  end

  return req
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
---@return any @ 返回qml的ClientInstance.replyToServer。注意0.5.12+版本不再需要json.decode
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
---@field skip? boolean @ 是否跳过移动。默认不跳过

--- 询问移动场上的一张牌。不可取消
---@param player ServerPlayer @ 移动的操作者
---@param params AskToMoveCardInBoardParams @ 各种变量
---@return { card: Card, from: ServerPlayer, to: ServerPlayer }? @ 选择的卡牌、起点玩家id和终点玩家id列表
function Room:askToMoveCardInBoard(player, params)
  params.exclude_ids = type(params.exclude_ids) == "table" and params.exclude_ids or {}

  local targetOne, targetTwo, skillName, flag, moveFrom, excludeIds, skip =
    params.target_one, params.target_two, params.skill_name,
    params.flag, params.move_from, params.exclude_ids, params.skip
  ---@cast excludeIds -nil

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
  local cardToMove = self:getCardOwner(result.cardId):getVirtualEquip(result.cardId) or Fk:getCardById(result.cardId)
  if not skip then
    self:moveCardTo(
      cardToMove,
      cardToMove.type == Card.TypeEquip and Player.Equip or Player.Judge,
      to,
      fk.ReasonPut,
      skillName,
      nil,
      true,
      player
    )
  end

  return { card = cardToMove, from = from, to = to }
end

---@class AskToChooseToMoveCardInBoardParams: AskToUseActiveSkillParams
---@field flag? "e" | "j" @ 限定可移动的区域，值为nil（装备区和判定区）、‘e’或‘j’
---@field exclude_ids? integer[] @ 本次不可移动的卡牌id
---@field froms? ServerPlayer[] @ 移动来源角色列表
---@field tos? ServerPlayer[] @ 移动目标角色列表

--- 询问一名玩家选择两名角色，在这两名角色之间移动场上一张牌
---@param player ServerPlayer @ 要做选择的玩家
---@param params AskToChooseToMoveCardInBoardParams @ 各种变量
---@return ServerPlayer[] @ 选择的两个玩家的列表，若未选择，返回空表
function Room:askToChooseToMoveCardInBoard(player, params)
  if params.flag then
    assert(table.contains({"e", "j", "ej", "je"}, params.flag))
  end
  params.cancelable = (params.cancelable == nil) and true or params.cancelable
  params.no_indicate = (params.no_indicate == nil) and true or params.no_indicate
  params.exclude_ids = type(params.exclude_ids) == "table" and params.exclude_ids or {}
  params.froms = params.froms or self.alive_players
  params.tos = params.tos or self.alive_players
  params.prompt = params.prompt or ("#AskToChooseToMoveCardInBoard:::"..params.skill_name)

  if #self:canMoveCardInBoard(params.flag, nil, params.exclude_ids) == 0 and not params.cancelable then return {} end

  local data = {
    flag = params.flag,
    skillName = params.skill_name,
    excludeIds = params.exclude_ids,
    froms = params.froms,
    tos = params.tos,
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
      return self:canMoveCardInBoard(params.flag, nil, params.exclude_ids)
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

--- 令两名玩家交换座位
---@param a ServerPlayer @ 玩家1
---@param b ServerPlayer @ 玩家2
---@param arrange_turn? boolean @ 是否更新本轮额定回合，默认是
function Room:swapSeat(a, b, arrange_turn)
  local ai, bi
  local players = self.players
  for i, v in ipairs(self.players) do
    if v == a then ai = i end
    if v == b then bi = i end
  end

  players[ai] = b
  players[bi] = a

  self:arrangeSeats()
  if arrange_turn == nil or arrange_turn then
    self:arrangeTurn()
  end
end

--- 将一名玩家移动至指定座位
---@param player ServerPlayer @ 被移动的玩家
---@param seat integer @ 目标座位
---@param arrange_turn? boolean @ 是否更新本轮额定回合，默认是
function Room:moveSeatTo(player, seat, arrange_turn)
  if player.seat ~= seat then
    local players = table.simpleClone(self.players)
    table.removeOne(players, player)
    table.insert(players, seat, player)
    self:arrangeSeats(players)

    if arrange_turn == nil or arrange_turn then
      self:arrangeTurn()
    end
  end
end

--- 将一名玩家移动至某人的下家/上家
---@param player ServerPlayer @ 被移动的玩家
---@param target ServerPlayer @ 目标玩家，移动成为这个玩家的下家（例如target为8号位，则移动后target为7号位，player为8号位）
---@param is_last boolean? @ 是否移动成为这个玩家的上家，默认否
---@param arrange_turn? boolean @ 是否更新本轮额定回合，默认是
function Room:moveSeatToNext(player, target, is_last, arrange_turn)
  is_last = is_last or false
  local players = table.simpleClone(self.players)
  if is_last then
    if player.next ~= target then
      table.removeOne(players, player)
      if target.seat == 1 then
        table.insert(players, player)
      else
        for i = 1, #players do
          if players[i] == target then
            table.insert(players, i, player)
            break
          end
        end
      end
    end
  else
    if target.next ~= player then
      table.removeOne(players, player)
      for i = 1, #players do
        if players[i] == target then
          table.insert(players, i + 1, player)
          break
        end
      end
    end
  end
  self:arrangeSeats(players)
  if arrange_turn == nil or arrange_turn then
    self:arrangeTurn()
  end
end

--- 按输入的角色表重新改变本轮额定回合。若无输入则更新本轮剩余额定回合
---@param players? ServerPlayer[]
function Room:arrangeTurn(players)
  if self.current == nil then return end
  local round_event = self.logic:getCurrentEvent():findParent(GameEvent.Round, true)
  if round_event then
    local turn_table = round_event.data.turn_table
    if turn_table then
      local new_turn_table = {}
      if players then
        new_turn_table = table.simpleClone(players)
      else
        local current = round_event.data.to
        if current == nil then return end
        for i = table.indexOf(self.players, current), #self.players do
          table.insert(new_turn_table, self.players[i])
        end
      end
      round_event.data.turn_table = new_turn_table
    end
  end
end

--- 洗牌。
function Room:shuffleDrawPile()
  AbstractRoom.shuffleDrawPile(self)

  self:doBroadcastNotify("ShuffleDrawPile", self.draw_pile)

  self.logic:trigger(fk.AfterDrawPileShuffle, nil, {})
end

-- 强制同步牌堆（用于在不因任何移动事件且不因洗牌导致的牌堆变动）
function Room:syncDrawPile()
  self:doBroadcastNotify("SyncDrawPile", self.draw_pile)
end

--- 结束一局游戏。
---@param winner string @ 获胜的身份，空字符串表示平局
function Room:gameOver(winner)
  self:setBanner("GameSummary", self:getGameSummary())

  for _, p in ipairs(self.players) do
    self:setPlayerProperty(p, "role_shown", true)

    -- 不知道某个C++ ServerPlayer此时的视角 只好都转回来
    -- 直接调C++的话还必须手搓cbor.encode 没一点脾气
    p._splayer:doNotify("ChangeSelf", cbor.encode(p._splayer:getId()))
  end

  -- 补充武将胜率更新
  if self:shouldUpdateWinRate() then
    local record = self:getBanner("InitialGeneral")
    for _, p in ipairs(self.players) do
      local mode = self:getSettings('gameMode')
      local result

      if p.id > 0 then
        result = self:victoryResult(winner, p.role)

        local general, deputyGeneral = p.general, p.deputyGeneral
        if record then
          for _, info in ipairs(record) do
            if info[1] == p.id then
              general, deputyGeneral = info[2], info[3]
            end
          end
        end

        self.room:updateGeneralWinRate(general, mode, p.role, result)

        if deputyGeneral ~= "" then
          self.room:updateGeneralWinRate(deputyGeneral, mode, p.role, result)
        end
      end
    end
  end

  ServerRoomBase.gameOver(self, winner)
end

--- 获取一局游戏的总结，包括每个玩家的回合数、回血、伤害、受伤、击杀
---@return table<integer, integer[]> @ 玩家id到总结的映射
function Room:getGameSummary()
  local summary = {}
  for _, p in ipairs(self.players) do
    -- 选将阶段直接房间解散的智慧 有点意思
    if p.seat == 0 then return summary end
    summary[p.seat] = { turn = 0, recover = 0, recoverBy = 0,
      damage = 0, damaged = 0, kill = 0, killList = {}, draw = 0,
      control = 0, scname = p._splayer:getScreenName()}
      -- 回合，回血，给人回血，伤害，受伤，击杀，击杀列表，获得牌，控制
  end

  local function incrementSummary(seat, key, value)
    summary[seat][key] = summary[seat][key] + (value or 1)
  end

  self.logic:getEventsOfScope(GameEvent.Turn, 1, function(e)
    incrementSummary(e.data.who.seat, "turn") -- 回合
    return false
  end, Player.HistoryGame)

  self.logic:getEventsOfScope(GameEvent.Recover, 1, function(e)
    local recover = e.data
    incrementSummary(recover.who.seat, "recover", recover.num) -- 回血
    if recover.recoverBy then
      incrementSummary(recover.recoverBy.seat, "recoverBy", recover.num) -- 回血
    end
    return false
  end, Player.HistoryGame)

  self.logic:getEventsOfScope(GameEvent.Death, 1, function(e)
    local killer = e.data.killer
    if killer then
      incrementSummary(killer.seat, "kill") -- 击杀
      table.insert(summary[killer.seat].killList, e.data.who.id)
    end
    return false
  end, Player.HistoryGame)

  self.logic:getActualDamageEvents(1, function(e)
    local damage = e.data
    if damage.from then
      incrementSummary(damage.from.seat, "damage", damage.damage) -- 伤害
    end
    incrementSummary(damage.to.seat, "damaged", damage.damage) -- 受伤
    return false
  end, nil, 1)

  self.logic:getEventsOfScope(GameEvent.MoveCards, 1, function(e)
    for _, move in ipairs(e.data) do
      if move.to and move.toArea == Card.PlayerHand then
        incrementSummary(move.to.seat, "draw", #move.moveInfo) -- 获得牌
      end
      if move.from and move.proposer and move.from ~= move.proposer then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerHand or info.fromArea == Card.PlayerEquip then
            incrementSummary(move.proposer.seat, "control") -- 使其他角色失去
          end
        end
      end
    end
    return false
  end, Player.HistoryGame)
  return summary
end

--- 获取可以移动场上牌的第一对目标。用于判断场上是否可以移动的牌
---@param flag? "e"|"j"|"ej" @ 判断移动的区域
---@param players? ServerPlayer[] @ 可被移动的玩家列表
---@param excludeIds? integer[] @ 不能移动的卡牌id
---@param targets? ServerPlayer[] @ 可移动至的玩家列表，默认为```players```
---@return ServerPlayer[] @ 第一对玩家列表，第一个是来源，第二个是目标 可能为空表
function Room:canMoveCardInBoard(flag, players, excludeIds, targets)
  if flag then
    assert(table.contains({"e", "j", "ej", "je"}, flag))
  end

  players = players or self.alive_players
  targets = targets or players
  excludeIds = type(excludeIds) == "table" and excludeIds or {}

  for _, from in ipairs(players) do
    local to = table.find(targets, function(p)
      return p ~= from and from:canMoveCardsInBoardTo(p, flag, excludeIds)
    end)
    if to then
      return { from, to }
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
  self:doBroadcastNotify("PrintCard", { name, suit, number })
  return cd
end

--- 刷新使命技状态
---@param player ServerPlayer
---@param skillName string
---@param failed? boolean
function Room:updateQuestSkillState(player, skillName, failed)
  assert(Fk.skills[skillName]:hasTag(Skill.Quest))

  self:setPlayerMark(player, MarkEnum.QuestSkillPreName .. skillName, failed and "failed" or "succeed")
  local updateValue = failed and 2 or 1

  self:doBroadcastNotify("UpdateQuestSkillUI", {
    player.id,
    skillName,
  })
end

--- 刷新所有武将脸旁边的技能图标状态
---@param player ServerPlayer
function Room:updateAllLimitSkillUI(player)
  for _, skill in ipairs(player.player_skills) do
    self:doBroadcastNotify("UpdateQuestSkillUI", {
      player.id,
      skill.name,
    })
  end
end

--- 废除区域
---@param player ServerPlayer @ 被废除区域的玩家
---@param playerSlots string | string[] @ 被废除区域的名称
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
        table.insertIfNeed(slotsToSeal, Player.JudgeSlot)

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
  self.logic:trigger(fk.AreaAborted, player, { slots = slotsToSeal })
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

--- 结束当前回合（不会终止结算）即结束当前阶段，且不执行本回合之后的阶段
function Room:endTurn()
  self.current:endCurrentPhase()
  local current_turn = self.logic:getCurrentEvent():findParent(GameEvent.Turn, true)
  if current_turn then
    current_turn.data.turn_end = true
  end
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
---@param player ServerPlayer @ 技能被无效的角色
---@param skill_name string @ 被无效的技能
---@param temp? TempMarkSuffix|"" @ 作用范围或其他后缀
---@param source_skill? string @ 控制失效与否的技能。（保证不会与其他控制技能互相干扰）
function Room:invalidateSkill(player, skill_name, temp, source_skill)
  temp = temp or ""
  source_skill = source_skill or skill_name
  local record = player:getTableMark(MarkEnum.InvalidSkills .. temp)
  record[skill_name] = record[skill_name] or {}
  table.insert(record[skill_name], source_skill)
  self:setPlayerMark(player, MarkEnum.InvalidSkills .. temp, record)
end

--- 移除技能的无效化状态
---@param player ServerPlayer @ 技能被有效的角色
---@param skill_name string @ 被有效的技能
---@param temp? TempMarkSuffix|"" @ 作用范围或其他后缀
---@param source_skill? string @ 控制生效与否的技能。（保证不会与其他控制技能互相干扰）
function Room:validateSkill(player, skill_name, temp, source_skill)
  temp = temp or ""
  source_skill = source_skill or skill_name
  local record = player:getTableMark(MarkEnum.InvalidSkills .. temp)
  record[skill_name] = record[skill_name] or {}
  table.removeOne(record[skill_name], source_skill)
  if #record[skill_name] == 0 then record[skill_name] = nil end
  self:setPlayerMark(player, MarkEnum.InvalidSkills .. temp, record)
end

--- 在判定或使用流程中，将使用或判定牌应用锁视转化，并返回转化后的牌
---@param id integer @ 牌id
---@param player ServerPlayer @ 使用者或判定角色
---@param judgeEvent boolean? @ 是否为判定事件
---@return Card @ 返回应用锁视后的牌
function Room:filterCard(id, player, judgeEvent)
  local ret = AbstractRoom.filterCard(self, id, player, judgeEvent)
  self:doBroadcastNotify("FilterCard", { id, player, judgeEvent })
  return ret
end

--- 进行待执行的额外回合
function Room:actExtraTurn()
  while #self.extra_turn_list > 0 do
    local data = table.remove(self.extra_turn_list, 1)
    data.who:gainAnExtraTurn(false, data.reason, data.phases, data.extra_data)
  end
end

---@deprecated @ 用actExtraTurn代替
Room.ActExtraTurn = Room.actExtraTurn

--- 获得一名角色的客户端手牌顺序
--- 本bug由玄蝶提供
---@param player ServerPlayer @ 角色
---@return integer[] @ 卡牌ID，有元素检测就是了……
function Room:getPlayerClientCards(player)
  local req = Request:new({player}, "GetPlayerHandcards") --FIXME: 需要一个假request
  local cards = player.player_cards[Player.Hand]
  req:setDefaultReply(player, cards)
  local result = req:getResult(player)
  -- printf("客户端返回组合：%s", table.map(result, function(e) return tostring(Fk:getCardById(e)) end))
  -- assert(isSame(cards, result), "客户端和服务端信息不符！")
  return result
end

--- 同步一名角色的客户端手牌顺序
---@param player ServerPlayer @ 角色
---@return integer[] @ 卡牌ID，有元素检测就是了……
function Room:syncPlayerClientCards(player)
  local cards = player.player_cards[Player.Hand]
  local result = self:getPlayerClientCards(player)
  -- printf("服务端此时组合：%s", table.concat(table.map(cards, function(e) return tostring(Fk:getCardById(e)) end), ","))
  -- printf("客户端返回组合：%s", table.concat(table.map(result, function(e) return tostring(Fk:getCardById(e)) end), ","))
  -- assert(table.isEqual(cards, result), "客户端和服务端信息不符！")
  if not table.isEqual(cards, result) then
    result = cards
  end
  player.player_cards[Player.Hand] = result
  self:doBroadcastNotify("SetPlayerHandCards", { player.id, result })
  return result
end

--- 禁止排序手牌，在此时点，客户端手牌顺序将应用于服务端手牌顺序
---@param player ServerPlayer @ 角色
---@param suffix string? @ 后缀，如“-turn”
function Room:banSortingHandcards(player, suffix)
  suffix = suffix or ""
  self:setPlayerMark(player, MarkEnum.SortProhibited .. suffix, 1)
  self:syncPlayerClientCards(player)
  --FIXME: 需要一个假request
end

--- 解禁排序手牌，配合banSortingHandcards使用。
---@param player ServerPlayer @ 角色
---@param suffix string? @ 后缀，如“-turn”，一般是你用banSortingHandcards时填入的后缀
function Room:unbanSortingHandcards(player, suffix)
  suffix = suffix or ""
  self:setPlayerMark(player, MarkEnum.SortProhibited .. suffix, 0)
end

---阶段性清理各种标记
---@param scope integer
function Room:clearHistory (scope)
  local suffixMap = {
    [Player.HistoryPhase] = "-phase", [Player.HistoryTurn] = "-turn", [Player.HistoryRound] = "-round",
  }
  local suffix = suffixMap[scope]
  for _, p in ipairs(self.players) do
    p:setCardUseHistory("", 0, scope)
    p:setSkillUseHistory("", 0, scope)
    p:setSkillBranchUseHistory("", "", 0, scope)
    for name, _ in pairs(p.mark) do
      if name:find(suffix, 1, true) then
        self:setPlayerMark(p, name, 0)
      end
    end
  end

  for cid, cmark in pairs(self.card_marks) do
    for name, _ in pairs(cmark) do
      if name:find(suffix, 1, true) then
        self:setCardMark(Fk:getCardById(cid), name, 0)
      end
    end
  end

  for name, _ in pairs(self.banners) do
    if name:find(suffix, 1, true) then
      self:setBanner(name, 0)
    end
  end

  for name, _ in pairs(self.tag) do
    if name:find(suffix, 1, true) then
      self:setTag(name, nil)
    end
  end

  for _, p in ipairs(self.players) do
    p:filterHandcards()
  end
end


--- 将一些牌洗入某个区域，不产生移动事件和动画（牌的原区域和目标区域仅限弃牌堆、摸牌堆、虚空区）
---@param cards integer|integer[]|Card|Card[] @ 牌
---@param area CardArea @ 目标区域
---@param areaCards? integer[] @ 若指定顺序，则输入新区域牌的id表
function Room:changeCardArea (cards, area, areaCards)
  local ret = AbstractRoom.changeCardArea(self, cards, area, areaCards)
  self:doBroadcastNotify("ChangeCardArea", {cards, area, areaCards or ret})
end


--- 将角色私人牌堆设置为指定牌（请确保这些牌已经在该角色的私人牌堆上）
---@param player ServerPlayer @ 角色
---@param pile string @ 牌堆名
---@param ids integer[] @ 要设置的牌id表
function Room:setPlayerPile(player, pile, ids)
  player.special_cards[pile] = ids
  self:doBroadcastNotify("SetPlayerPile", { player.id, pile, ids })
end

--- 展示一堆牌（注意，这样子是不会过锁视技的）
---@param cards integer|integer[]|Card|Card[] @ 要展示的牌
---@param from? ServerPlayer
function Room:showCards(cards, from)
  cards = Card:getIdList(cards)
  local src
  if from then src = from.id end
  self:sendLog{
    type = "#ShowCard",
    from = src,
    card = cards,
  }

  --[[ -- 原版

  self:doBroadcastNotify("ShowCard", {
    from = src,
    cards = cards,
  })
  self:sendFootnote(cards, {
    type = "##ShowCard",
    from = src,
  })
  
  --]]

  local n = 0
  if self.logic:getCurrentEvent().event == GameEvent.SkillEffect then
    n = self.logic:getCurrentEvent().id
  end

  self:doBroadcastNotify("ShowCard", { cards, src, n })

  self.logic:trigger(fk.CardShown, from, { cardIds = cards })
end

--- 将虚拟牌展示到桌面（仅动画）
---@param card Card | Card[] @ 需要展示的牌
---@param player? ServerPlayer @ 牌来自谁的手牌区
---@param footnote? LogMessage @ 脚注
---@param event_id? integer @ 当前事件的ID（用于清理UI处理区的卡）
function Room:showVirtualCard(card, player, footnote, event_id)
  self:doBroadcastNotify("ShowVirtualCard", { card, player and player.id, footnote, event_id or 0 })
end

--- 将桌面上的虚拟牌在移出（仅动画）
---@param ids integer | integer[]
function Room:destroyTableCard(ids)
  self:doBroadcastNotify("DestroyTableCard", type(ids) == "table" and ids or { ids })
end

--- 将桌面上的在该事件之后进入的卡牌移出（仅动画）
---@param id integer
function Room:destroyTableCardByEvent(id)
  self:doBroadcastNotify("DestroyTableCardByEvent", id)
end


return Room
