---@class Request : Object
---@field public room Room
---@field public players ServerPlayer[]
---@field public n integer @ 产生n个winner后，询问直接结束
---@field public accept_cancel? boolean @ 是否将取消也算作是收到肯定答复
---@field public ai_start_time integer? @ 只剩AI思考开始的时间（微秒），delay专用
---@field public timeout? integer @ 本次耗时（秒），默认为房间内配置的出手时间
---@field public command string @ command自然就是command
---@field public data table<integer, any> @ 每个player对应的询问数据
---@field public default_reply table<integer, any> @ 玩家id - 默认回复内容 默认空串
---@field public send_encode boolean? @ 是否需要对data使用json.encode，默认true
---@field public receive_decode boolean? @ 是否需要对reply使用json.decode，默认true
---@field private send_success table<fk.ServerPlayer, boolean> @ 数据是否发送成功，不成功的后面全部视为AI
---@field public result table<integer, any> @ 玩家id - 回复内容 nil表示完全未回复
---@field public winners ServerPlayer[] @ 按肯定回复先后顺序排序 由于有概率所有人烧条 可能会空
---@field public overtimes ServerPlayer[] @ 超时的玩家
---@field public luck_data any? @ 是否是询问手气卡 TODO: 有需求的话把这个通用化一点
---@field private pending_requests table<fk.ServerPlayer, integer[]> @ 一控多时暂存的请求
---@field private _asked boolean? @ 是否询问过了
---@field public focus_players? ServerPlayer[] @ 要moveFocus的玩家们 默认参与者
---@field public focus_text? string @ 要moveFocus的文字 默认self.command
---@field public no_time_waste_check? boolean
local Request = class("Request")

-- TODO: 懒得思考了
-- 手气卡用：目前暂时写死一个属性而不是给函数参数；
-- player有个属性保存自己剩余手气卡次数
-- request有个luck_data属性来处理OK消息
-- 若还能再用一次，那就重新发Request并继续等

---@param command string
---@param players ServerPlayer|ServerPlayer[]
---@param n? integer
function Request:initialize(players, command, n)
  if (not players[1]) and players.class then players = { players } end
  assert(#players > 0)
  self.command = command
  self.players = players
  self.n = n or #players

  -- 剩下的需要自己构造后修改相关值，构造函数只给四个
  local room = players[1].room
  self.room = room
  self.data = {}
  self.default_reply = {}
  self.timestamp = math.ceil(os.getms() / 1000)
  self.timeout = room.timeout
  self.send_encode = true
  self.receive_decode = true -- 除了几个特殊字符串之外都decode

  self.pending_requests = setmetatable({}, { __mode = "k" })
  self.send_success = setmetatable({}, { __mode = "k" })
  self.result = {}
  self.winners = {}
  self.overtimes = {}
end

function Request:__tostring()
  return string.format("<Request '%s'>", self.command)
end

---@param player ServerPlayer
---@param data any
function Request:setData(player, data)
  self.data[player.id] = data
end

---@param player ServerPlayer
---@param data any @ 注意不要json.encode
function Request:setDefaultReply(player, data)
  self.default_reply[player.id] = data
end

--- 获取本次Request中此人的回复，若还未询问过，那么先询问
--- * <any>: 成功发出回复 获取的是decode后的回复
--- * "" (空串): 发出了“取消” 或者烧完了绳子 反正就是取消
---@param player ServerPlayer
---@return any
function Request:getResult(player)
  if not self._asked then self:ask() end
  return self.result[player.id]
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
    controller:doNotify("ChangeSelf", cbor.encode(player.id))
  end

  -- 发送请求数据并将控制者标记为烧条中
  local jsonData = self.data[player.id]
  if self.send_encode then jsonData = cbor.encode(jsonData) end
  -- FIXME: 这里确认数据是否发送的环节一定要写在C++代码中
  self.send_success[controller] = controller:getState() == fk.Player_Online
  controller:doRequest(self.command, jsonData, self.timeout, self.timestamp)
  controller:setThinking(true)
end

-- 检查一下该玩家是否已经有答复了，若为AI则直接计算出回复
-- 一般来说，在一次同时询问中，需要人类玩家全部回复完了，AI才进行回复
---@param player ServerPlayer
---@param use_ai boolean
---@return any
function Request:_checkReply(player, use_ai)
  local room = self.room

  -- 此段代码为测试程序专用 用于暂时中断房间
  -- 类似调试器中的断点
  local breakpoints = room:getTag("__test_breakpoints")
  if breakpoints then
    for i, br in ipairs(breakpoints) do
      local p, command, fn = br[1], br[2], br[3]
      if p == player and command == self.command and fn(self.data[player.id]) then
        table.remove(breakpoints, i)
        coroutine.yield("__handleRequest")
        break
      end
    end
  end

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
          -- 此处是CBOR化的影响
          -- 除了默认的__notready和__cancel之外其他实际的消息必定是cbor编码过的
          -- 这个函数的末尾强制用了cbor.decode，但是此处判断的时机还非常早
          -- 所以手动判一下好了 不解析了
          if reply ~= "__cancel" and reply ~= "\x68__cancel" then
            local pdata = luck_data[player.id]
            pdata.luckTime = pdata.luckTime - 1
            luck_data.discardInit(room, player)
            luck_data.drawInit(room, player, pdata.num, pdata.fix_ids)
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
      player.ai.data = self.data[player.id]
      reply = Pcall(player.ai.makeReply, player.ai)
    else
      -- 还没轮到AI呢，所以需要标记为未答复
      reply = "__notready"
    end
  end

  local ok, ret = pcall(cbor.decode, reply)
  if ok then
    reply = ret
  end

  if reply == '' then reply = '__cancel' end
  return reply
end

function Request:ask()
  if self._asked then return end

  local room = self.room
  -- 0. 设置计时器，防止因无人回复一直等下去
  room.room:setRequestTimer(self.timeout * 1000 + 500)

  local players = table.simpleClone(self.players)
  local currentTime = os.time()
  local resume_reason = "unknown"

  -- 设置所有人为未思考
  for _, p in ipairs(players) do
    p.serverplayer:setThinking(false)
  end

  -- 发送focus
  room:notifyMoveFocus(self.focus_players or self.players, self.focus_text or self.command,
    math.floor(self.timeout * 1000))

  -- 1. 向所有人发送询问请求
  room.logic:trigger(fk.BeforeRequestAsk, nil, self, true)
  for _, p in ipairs(players) do
    self:_sendPacket(p)
  end

  -- 2. 进入循环等待，结束条件为已有n个回复或者超时或者有人点了
  --    若很多人都取消了导致最多回复数达不到n了，那么也结束
  local replied_players = 0
  while true do
    local changed = false
    -- 若投降则直接结束全部询问，若超时则踢掉所有人类玩家（让AI还可计算）
    if room.hasSurrendered then break end
    local elapsed = os.time() - currentTime
    if self.timeout - elapsed <= 0 or resume_reason == "request_timer" then
      for i = #players, 1, -1 do
        table.insert(self.overtimes, players[i])
        if self.send_success[players[i].serverplayer] then
          table.remove(players, i)
        end
      end
    end

    -- 若players中只剩人机，那么允许人机进行计算
    if table.every(players, function(p)
      return p.serverplayer:getState() ~= fk.Player_Online or not
        self.send_success[p.serverplayer]
    end) then
      self.ai_start_time = os.getms()
    end
    local use_ai = self.ai_start_time ~= nil

    -- 轮询所有参与回答的玩家，如果作出了答复，那么就把他从名单移除；
    -- 然后如果作出的是“肯定”答复，那么添加到winner里面
    for i = #players, 1, -1 do
      local player = players[i]
      local reply = self.timeout > 0 and self:_checkReply(player, use_ai) or "__notready"

      if reply ~= "__notready" then
        self.result[player.id] = reply
        table.remove(players, i)
        replied_players = replied_players + 1
        changed = true

        if reply ~= "__cancel" or self.accept_cancel then
          table.insert(self.winners, player)
          if #self.winners >= self.n then
            -- winner数量已经足够，剩下的人不用算了
            for _, p in ipairs(players) do
              -- 避免触发后续的烧条检测
              if self.result[p.id] == nil then
                self.result[p.id] = "__failed_in_race"
              end
            end
            players = {} -- 清空参与者名单
            break -- 注意外面还有一层循环
          end
        end
      end
    end

    if #players == 0 then break end
    if #self.winners >= self.n then break end

    -- 防止万一，如果AI算完后还是有机器人notready的话也别等了
    -- 不然就永远别想被唤醒了
    if self.ai_start_time then break end

    -- 需要等待呢，等待被唤醒吧，唤醒后继续下一次轮询检测
    if not changed then
      if room._test_disable_delay then
        resume_reason = "request_timer"
      else
        resume_reason = coroutine.yield("__handleRequest")
      end
    end
  end

  room.room:destroyRequestTimer()
  self:_finish()

  self._asked = true

  if not room.hasSurrendered then
    room.logic:trigger(fk.AfterRequestAsk, nil, self, true)
  end
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
function Request:_finish()
  local room = self.room
  surrenderCheck(room)

  for _, p in ipairs(self.players) do
    p.serverplayer:setThinking(false)
    -- 这个什么timewaste_count也该扔了
    if self.result[p.id] == "__failed_in_race" then
      p:doNotify("CancelRequest", "")
      self.result[p.id] = self.default_reply[p.id] or ""
    end
    if self.result[p.id] == nil then
      self.result[p.id] = self.default_reply[p.id] or ""
      if not self.no_time_waste_check then
        p._timewaste_count = p._timewaste_count + 1
        if p._timewaste_count >= 3 and p.serverplayer:getState() == fk.Player_Online then
          p._timewaste_count = 0
          p.serverplayer:emitKick()
        end
      end
    else
      p._timewaste_count = 0
    end
    if self.result[p.id] == "__cancel" then
      self.result[p.id] = (not self.accept_cancel) and self.default_reply[p.id] or ""
    end
  end
  room.last_request = self

  for _, isHuman in pairs(self.send_success) do
    if not self.ai_start_time then break end
    if not isHuman then
      local to_delay = 800 - (os.getms() - self.ai_start_time) / 1000
      if to_delay > 0 then room:delay(to_delay) end
      break
    end
  end
end

return Request
