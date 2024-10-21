---@class Request : Object
---@field public room Room
---@field public players ServerPlayer[]
---@field public n integer @ n个人做出回复后，询问结束
---@field public accept_cancel? boolean @ 是否将取消也算作是收到回复
---@field public ai_start_time integer? @ 只剩AI思考开始的时间（微秒），delay专用
---@field public timeout? integer @ 本次耗时（秒），默认为房间内配置的出手时间
---@field public command string @ command自然就是command
---@field public data table<integer, any> @ 每个player对应的询问数据
---@field public default_reply table<integer, any> @ 玩家id - 默认回复内容
---@field public send_json boolean? @ 是否需要对data使用json.encode，默认true
---@field public receive_json boolean? @ 是否需要对reply使用json.decode，默认true
---@field private send_success table<fk.ServerPlayer, boolean> @ 数据是否发送成功，不成功的后面全部视为AI
---@field public result table<integer, any> @ 玩家id - 回复内容 nil表示完全未回复
---@field public luck_data any? @ 是否是询问手气卡 TODO: 有需求的话把这个通用化一点
---@field private pending_requests table<fk.ServerPlayer, integer[]> @ 一控多时暂存的请求
local Request = class("Request")

-- TODO: 懒得思考了
-- 手气卡用：目前暂时写死一个属性而不是给函数参数；
-- player有个属性保存自己剩余手气卡次数
-- request有个luck_data属性来处理OK消息
-- 若还能再用一次，那就重新发Request并继续等

---@param command string
---@param players ServerPlayer[]
---@param n? integer
function Request:initialize(command, players, n)
  assert(#players > 0)
  self.command = command
  self.players = players
  self.n = n or #players

  -- 剩下的需要自己构造后修改相关值，构造函数只给四个
  local room = players[1].room
  self.room = room
  self.data = {}
  self.default_reply = {}
  for _, p in ipairs(players) do self.default_reply[p.id] = "__cancel" end
  self.timestamp = math.ceil(os.getms() / 1000)
  self.timeout = room.timeout
  self.send_json = true
  self.receive_json = true -- 除了几个特殊字符串之外都decode

  self.pending_requests = setmetatable({}, { __mode = "k" })
  self.send_success = setmetatable({}, { __mode = "k" })
  self.result = {}
end

function Request:__tostring()
  return "<Request>"
end

function Request:setData(player, data)
  self.data[player.id] = data
end

function Request:setDefaultReply(player, data)
  self.default_reply[player.id] = data
end

-- 将相应请求数据发给player
-- 不能向thinking中的玩家发送，这种情况下暂存起来等待收到答复后
---@param player ServerPlayer
function Request:_sendPacket(player)
  local controller = player.serverplayer

  -- 若正在烧条，则不发，将这个需要请求的玩家id存起来后面用
  if controller:thinking() then
    self.pending_requests[controller] = self.pending_requests[controller] or {}
    table.insert(self.pending_requests[controller], player.id)
    return
  end

  -- 若控制者目前的视角不是player，先发个数据指示切换视角
  if not table.contains(player._observers, controller) then
    local from = table.find(self.room.players, function(p)
      return table.contains(p._observers, controller)
    end)

    -- 切换视角
    table.removeOne(from._observers, controller)
    table.insert(player._observers, controller)
    controller:doNotify("ChangeSelf", tostring(player.id))
  end

  -- 发送请求数据并将控制者标记为烧条中
  local jsonData = self.data[player.id]
  if self.send_json then jsonData = json.encode(jsonData) end
  -- FIXME: 这里确认数据是否发送的环节一定要写在C++代码中
  self.send_success[controller] = controller:getState() == fk.Player_Online
  controller:doRequest(self.command, jsonData, self.timeout, self.timestamp)
  controller:setThinking(true)
end

-- 检查一下该玩家是否已经有答复了，若为AI则直接计算出回复
-- 一般来说，在一次同时询问中，需要人类玩家全部回复完了，AI才进行回复
---@param player ServerPlayer
---@param use_ai boolean
function Request:_checkReply(player, use_ai)
  local room = self.room

  -- 若被人类玩家控制着，靠人类玩家自己分析了
  -- 否则交给该Player自己的AI进行考虑，换言之AI控人没有效果（不会故意杀队友）
  local controller = player.serverplayer
  local state = controller:getState()
  local reply

  if state == fk.Player_Online and self.send_success[controller] then
    if not table.contains(player._observers, controller) then
      -- 若控制者的视角不在自己，那就不管了
      reply = "__notready"
    else
      reply = controller:waitForReply(0)
      if reply ~= "__notready" then
        controller:setThinking(false)
        -- FIXME: 写的依托且不考虑控制 后面看情况改！
        if self.luck_data then
          local luck_data = self.luck_data
          if reply ~= "__cancel" then
            local pdata = luck_data[player.id]
            pdata.luckTime = pdata.luckTime - 1
            luck_data.discardInit(room, player)
            luck_data.drawInit(room, player, pdata.num)
            if pdata.luckTime > 0 then
              self:setData(player, { "AskForLuckCard", "#AskForLuckCard:::" .. pdata.luckTime })
              self:_sendPacket(player)
              reply = "__notready"
            end
          end
        else
          local pending_list = self.pending_requests[controller]
          if pending_list and #pending_list > 0 then
            local pid = table.remove(pending_list, 1)
            self:_sendPacket(room:getPlayerById(pid))
          end
        end
      end
    end
  else
    room:checkNoHuman()
    if use_ai then
      player.ai.command = self.command
      -- FIXME: 后面进行SmartAI的时候准备爆破此处
      -- player.ai.data = self.data[player.id]
      player.ai.jsonData = self.data[player.id]
      if player.ai:isInstanceOf(RandomAI) then
        reply = "__cancel"
      else
        reply = player.ai:makeReply()
      end
    else
      -- 还没轮到AI呢，所以需要标记为未答复
      reply = "__notready"
    end
  end

  return reply
end

function Request:getWinners()
  local ret = {}
  for _, p in ipairs(self.players) do
    local result = self.result[p.id]
    if result and result ~= "" then
      table.insert(ret, p)
    end
  end
  return ret
end

function Request:ask()
  local room = self.room
  -- 0. 设置计时器，防止因无人回复一直等下去
  room.room:setRequestTimer(self.timeout * 1000 + 500)

  local players = table.simpleClone(self.players)
  local currentTime = os.time()

  -- 1. 向所有人发送询问请求
  for _, p in ipairs(players) do
    self:_sendPacket(p)
  end

  -- 2. 进入循环等待，结束条件为已有n个回复或者超时或者有人点了
  --    若很多人都取消了导致最多回复数达不到n了，那么也结束
  local replied_players = 0
  local ready_players = 0
  while true do
    local changed = false
    -- 判断1：若投降则直接结束全部询问，若超时则踢掉所有人类玩家（这样AI还可计算）
    if room.hasSurrendered then break end
    local elapsed = os.time() - currentTime
    if self.timeout - elapsed <= 0 then
      for i = #players, 1, -1 do
        if self.send_success[players[i].serverplayer] then
          table.remove(players, i)
        end
      end
    end

    if table.every(players, function(p)
      return p.serverplayer:getState() ~= fk.Player_Online or not
        self.send_success[p.serverplayer]
    end) then
      self.ai_start_time = os.getms()
    end

    -- 判断2：收到足够多回复了
    local use_ai = self.ai_start_time ~= nil

    for i = #players, 1, -1 do
      local player = players[i]
      local reply = self:_checkReply(player, use_ai)

      if reply ~= "__notready" then
        if reply ~= "__cancel" and self.receive_json then
          reply = json.decode(reply)
        end
        self.result[player.id] = reply
        table.remove(players, i)
        replied_players = replied_players + 1
        changed = true

        if reply ~= "__cancel" or self.accept_cancel then
          ready_players = ready_players + 1
          if ready_players >= self.n then
            for _, p in ipairs(self.players) do
              -- 避免触发后续的烧条检测
              if self.result[p.id] == nil then
                self.result[p.id] = "__failed_in_race"
              end
            end
            break -- 注意外面还有一层循环
          end
        end
      end
    end

    if #players + ready_players < self.n then break end
    if ready_players >= self.n then break end

    -- 防止万一，如果AI算完后还是有机器人notready的话也别等了
    -- 不然就永远别想被唤醒了
    if self.ai_start_time then break end

    -- 需要等待呢，等待被唤醒吧
    if not changed then
      coroutine.yield("__handleRequest")
    end
  end

  room.room:destroyRequestTimer()
  self:finish()
end

local function surrenderCheck(room)
  if not room.hasSurrendered then return end
  local player = table.find(room.players, function(p)
    return p.surrendered
  end)
  if not player then
    room.hasSurrendered = false
    return
  end
  room:broadcastProperty(player, "surrendered")
  local mode = Fk.game_modes[room.settings.gameMode]
  local winner = Pcall(mode.getWinner, mode, player)
  if winner ~= "" then
    room:gameOver(winner)
  end

  -- 以防万一
  player.surrendered = false
  room:broadcastProperty(player, "surrendered")
  room.hasSurrendered = false
end

-- 善后工作，主要是result规范化、投降检测等
function Request:finish()
  local room = self.room
  surrenderCheck(room)
  -- FIXME: 这里QML中有个bug，这个命令应该是用来暗掉玩家面板的
  -- room:doBroadcastNotify("CancelRequest", "")
  for _, p in ipairs(self.players) do
    p.serverplayer:setThinking(false)
    if self.result[p.id] == nil then
      self.result[p.id] = self.default_reply[p.id]
      p._timewaste_count = p._timewaste_count + 1
      if p._timewaste_count >= 3 and p.serverplayer:getState() == fk.Player_Online then
        p._timewaste_count = 0
        p.serverplayer:emitKick()
      end
    else
      p._timewaste_count = 0
    end
    if self.result[p.id] == "__cancel" then
      self.result[p.id] = ""
    end
    if self.result[p.id] == "__failed_in_race" then
      self.result[p.id] = nil
    end
  end
  room.last_request = self

  for _, isHuman in pairs(self.send_success) do
    if not self.ai_start_time then break end
    if not isHuman then
      local to_delay = 500 - (os.getms() - self.ai_start_time) / 1000
      room:delay(to_delay)
      break
    end
  end
end

return Request
