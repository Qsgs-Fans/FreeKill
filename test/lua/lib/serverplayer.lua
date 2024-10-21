-- 仿效 swig 中 class ServerPlayer 的接口制作，为了便于测试

local ServerPlayer = class("fk.ServerPlayer")
local io = fk.io

fk.Player_Invalid = 0
fk.Player_Online = 1
fk.Player_Trust = 2
fk.Player_Run = 3
fk.Player_Leave = 4
fk.Player_Robot = 5
fk.Player_Offline = 6

local function colorConvert(log)
  log = log:gsub('<font color="#0598BC"><b>', string.char(27) .. "[34;1m")
  log = log:gsub('<font color="#0C8F0C"><b>', string.char(27) .. "[32;1m")
  log = log:gsub('<font color="#CC3131"><b>', string.char(27) .. "[31;1m")
  log = log:gsub('<font color="red"><b>', string.char(27) .. "[31;1m")
  log = log:gsub('<font color="black"><b>', string.char(27) .. "[0;1m")
  log = log:gsub('<font color="#0598BC">', string.char(27) .. "[34m")
  log = log:gsub('<font color="blue">', string.char(27) .. "[34m")
  log = log:gsub('<font color="#0C8F0C">', string.char(27) .. "[32m")
  log = log:gsub('<font color="green">', string.char(27) .. "[32m")
  log = log:gsub('<font color="#CC3131">', string.char(27) .. "[31m")
  log = log:gsub('<font color="red">', string.char(27) .. "[31m")
  log = log:gsub('<font color="grey">', string.char(27) .. "[90m")
  log = log:gsub("<b>", fk.BOLD)
  log = log:gsub("</b></font>", fk.RST)
  log = log:gsub("</font>", fk.RST)
  log = log:gsub("<b>", fk.BOLD)
  log = log:gsub("</b>", fk.RST)

  log = log:gsub("<br>", "\n")
  log = log:gsub("<br/>", "\n")
  log = log:gsub("<br />", "\n")
  return log
end

---@param msg LogMessage
local function parseMsg(msg, nocolor)
  local self = Fk:currentRoom()
  local data = msg
  local function getPlayerStr(pid, color)
    if nocolor then color = "white" end
    if not pid then
      return ""
    end
    local p = self:getPlayerById(pid)
    local str = '<font color="%s"><b>%s</b></font>'
    if p.general == "anjiang" and (p.deputyGeneral == "anjiang"
      or not p.deputyGeneral) then
      local ret = Fk:translate("seat#" .. p.seat)
      return string.format(str, color, ret)
    end

    local ret = p.general
    ret = Fk:translate(ret)
    if p.deputyGeneral and p.deputyGeneral ~= "" then
      ret = ret .. "/" .. Fk:translate(p.deputyGeneral)
    end
    ret = string.format(str, color, ret)
    return ret
  end

  local from = getPlayerStr(data.from, "#0C8F0C")

  local to = data.to or Util.DummyTable
  local to_str = {}
  for _, id in ipairs(to) do
    table.insert(to_str, getPlayerStr(id, "#CC3131"))
  end
  to = table.concat(to_str, ", ")

  local card = data.card or Util.DummyTable
  local allUnknown = true
  local unknownCount = 0
  for _, id in ipairs(card) do
    if id ~= -1 then
      allUnknown = false
    else
      unknownCount = unknownCount + 1
    end
  end

  if allUnknown then
    card = ""
  else
    local card_str = {}
    for _, id in ipairs(card) do
      table.insert(card_str, Fk:getCardById(id, true):toLogString())
    end
    if unknownCount > 0 then
      table.insert(card_str, Fk:translate("unknown_card")
        .. unknownCount == 1 and "x" .. unknownCount or "")
    end
    card = table.concat(card_str, ", ")
  end

  local function parseArg(arg)
    arg = arg or ""
    arg = Fk:translate(arg)
    arg = string.format('<font color="%s"><b>%s</b></font>', nocolor and "white" or "#0598BC", arg)
    return arg
  end

  local arg = parseArg(data.arg)
  local arg2 = parseArg(data.arg2)
  local arg3 = parseArg(data.arg3)

  local log = Fk:translate(data.type)
  log = string.gsub(log, "%%from", from)
  log = string.gsub(log, "%%to", to)
  log = string.gsub(log, "%%card", card)
  log = string.gsub(log, "%%arg2", arg2)
  log = string.gsub(log, "%%arg3", arg3)
  log = string.gsub(log, "%%arg", arg)

  return colorConvert(log)
end

local function processPrompt(prompt)
  local data = prompt:split(":")
  local room = Fk:currentRoom()
  local raw = Fk:translate(data[1]);
  local src = tonumber(data[2]);
  local dest = tonumber(data[3]);
  if src then raw = raw:gsub("%%src", Fk:translate(room:getPlayerById(src).general)) end
  if dest then raw = raw:gsub("%%dest", Fk:translate(room:getPlayerById(dest).general)) end
  if data[5] then raw = raw:gsub("%%arg2", Fk:translate(data[5])) end
  if data[4] then raw = raw:gsub("%%arg", Fk:translate(data[4])) end
  return colorConvert(raw)
end

--- separated moves to many moves(one card per move)
---@param moves CardsMoveStruct[]
local function separateMoves(moves)
  local ret = {}  ---@type CardsMoveInfo[]
  for _, move in ipairs(moves) do
    for _, info in ipairs(move.moveInfo) do
      table.insert(ret, {
        ids = {info.cardId},
        from = move.from,
        to = move.to,
        toArea = move.toArea,
        fromArea = info.fromArea,
        moveReason = move.moveReason,
        specialName = move.specialName,
        fromSpecialName = info.fromSpecialName,
        proposer = move.proposer,
      })
    end
  end
  return ret
end

--- merge separated moves that information is the same
local function mergeMoves(moves)
  local ret = {}
  local temp = {}
  for _, move in ipairs(moves) do
    local info = string.format("%q,%q,%q,%q,%s,%s,%q",
      move.from, move.to, move.fromArea, move.toArea,
      move.specialName, move.fromSpecialName, move.proposer)
    if temp[info] == nil then
      temp[info] = {
        ids = {},
        from = move.from,
        to = move.to,
        fromArea = move.fromArea,
        toArea = move.toArea,
        moveReason = move.moveReason,
        specialName = move.specialName,
        fromSpecialName = move.fromSpecialName,
        proposer = move.proposer,
      }
    end
    table.insert(temp[info].ids, move.ids[1])
  end
  for _, v in pairs(temp) do
    table.insert(ret, v)
  end
  return ret
end

local function sendMoveCardLog(move)
  local client = Fk:currentRoom() ---@class Client
  if #move.ids == 0 then return end
  local hidden = table.contains(move.ids, -1)
  local msgtype

  if move.toArea == Card.PlayerHand then
    if move.fromArea == Card.PlayerSpecial then
      print(parseMsg({
        type = "$GetCardsFromPile",
        from = move.to,
        arg = move.fromSpecialName,
        arg2 = #move.ids,
        card = move.ids,
      }))
    elseif move.fromArea == Card.DrawPile then
      print(parseMsg({
        type = "$DrawCards",
        from = move.to,
        card = move.ids,
        arg = #move.ids,
      }))
    elseif move.fromArea == Card.Processing then
      print(parseMsg({
        type = "$GotCardBack",
        from = move.to,
        card = move.ids,
        arg = #move.ids,
      }))
    elseif move.fromArea == Card.DiscardPile then
      print(parseMsg({
        type = "$RecycleCard",
        from = move.to,
        card = move.ids,
        arg = #move.ids,
      }))
    elseif move.from then
      print(parseMsg({
        type = "$MoveCards",
        from = move.from,
        to = { move.to },
        arg = #move.ids,
        card = move.ids,
      }))
    else
      print(parseMsg({
        type = "$PreyCardsFromPile",
        from = move.to,
        card = move.ids,
        arg = #move.ids,
      }))
    end
  elseif move.toArea == Card.PlayerEquip then
    print(parseMsg({
      type = "$InstallEquip",
      from = move.to,
      card = move.ids,
    }))
  elseif move.toArea == Card.PlayerJudge then
    if move.from ~= move.to and move.fromArea == Card.PlayerJudge then
      print(parseMsg({
        type = "$LightningMove",
        from = move.from,
        to = { move.to },
        card = move.ids,
      }))
    elseif move.from then
      print(parseMsg({
        type = "$PasteCard",
        from = move.from,
        to = { move.to },
        card = move.ids,
      }))
    end
  elseif move.toArea == Card.PlayerSpecial then
    print(parseMsg({
      type = "$AddToPile",
      arg = move.specialName,
      arg2 = #move.ids,
      from = move.to,
      card = move.ids,
    }))
  elseif move.fromArea == Card.PlayerEquip then
    print(parseMsg({
      type = "$UninstallEquip",
      from = move.from,
      card = move.ids,
    }))
  -- elseif move.toArea == Card.Processing then
    -- nop
  elseif move.from and move.toArea == Card.DrawPile then
    msgtype = hidden and "$PutCard" or "$PutKnownCard"
    print(parseMsg({
      type = msgtype,
      from = move.from,
      card = move.ids,
      arg = #move.ids,
    }))
  elseif move.toArea == Card.DiscardPile then
    if move.moveReason == fk.ReasonDiscard then
      if move.proposer and move.proposer ~= move.from then
        print(parseMsg({
          type = "$DiscardOther",
          from = move.from,
          to = {move.proposer},
          card = move.ids,
          arg = #move.ids,
        }))
      else
        print(parseMsg({
          type = "$DiscardCards",
          from = move.from,
          card = move.ids,
          arg = #move.ids,
        }))
      end
    elseif move.moveReason == fk.ReasonPutIntoDiscardPile then
      print(parseMsg({
        type = "$PutToDiscard",
        card = move.ids,
        arg = #move.ids,
      }))
    end
  -- elseif move.toArea == Card.Void then
    -- nop
  end
end

function ServerPlayer:initialize(id)
  self.id = id
  self.screenName = "player" .. id
  self.state = fk.Player_Online
  self.died = false
  self._busy = false
  self._thinking = false
end

function ServerPlayer:getId() return self.id end
function ServerPlayer:setId(id) self.id = id end
function ServerPlayer:getScreenName() return self.screenName end
function ServerPlayer:getAvatar() return "zhouyu" end
function ServerPlayer:getState() return self.state end
function ServerPlayer:setState(state) self.state = state end
function ServerPlayer:isDied() return self.died end
function ServerPlayer:setDied(died) self.died = died end

local function tr(str)
  return string.format("%s(%s)", Fk:translate(str), str)
end

local function trcid(cid)
  local card = Fk:getCardById(cid)
  return colorConvert(card:toLogString()) .. "(" .. cid .. ")"
end

local function help_rp_yn()
  print(fk.GRAY .."  (reply格式：n或N表示取消，其余确定，如reply n)" .. fk.RST)
end

local function help_rp_choices()
  print(fk.GRAY .."  (reply格式：直接输入文本，有多个则用空格分隔，如：reply kill)" .. fk.RST)
end

local request_processors = {
  ["AskForGeneral"] = function(j)
    local data = json.decode(j)
    io.write(string.format("请选择 %d 名武将: ", data[2]))
    for _, g in ipairs(data[1]) do
      io.write(tr(g) .. " ")
    end
    io.write("\n")
    help_rp_choices()
  end,
  ["PlayCard"] = function()
    print("出牌阶段，请进行操作")
  end,
  ["AskForSkillInvoke"] = function(j)
    local data = json.decode(j)
    local skill = data[1]
    local prompt = data[2]
    if prompt then prompt = processPrompt(prompt)
    else prompt = string.format("你是否发动技能 %s", tr(skill)) end
    print(prompt)
    help_rp_yn()
  end,
  ["AskForUseCard"] = function(j)
    local cardname, pattern, prompt, _, extra_data, disabledSkillNames =
      table.unpack(json.decode(j))
    if prompt then prompt = processPrompt(prompt)
    else prompt = string.format("请使用卡牌 %s", tr(cardname)) end
    print(prompt)
  end,
  ["AskForUseActiveSkill"] = function(j)
    local skill_name, prompt, cancelable, extra_data =
      table.unpack(json.decode(j))
    if prompt then prompt = processPrompt(prompt)
    else prompt = string.format("请使用技能 %s", tr(skill_name)) end
    print(prompt)
  end,
}
function ServerPlayer:doRequest(cmd, j)
  if self.id == 1 then
    io.write(fk.YELLOW .. "[!] " .. fk.RST)
    if request_processors[cmd] then
      request_processors[cmd](j)
    else
      print(cmd, j)
    end
  end
end

local cmd_help = function()
	io.write(""
		.. fk.BLUE .."  <回车>".. fk.CARET .."重复执行上一条命令\n"
		.. fk.BLUE .."  help/h".. fk.CARET .."查看这条帮助\n"
		.. fk.BLUE .."  dbg".. fk.CARET .."使用Debugger\n"
		.. fk.BLUE .."  reply/rp".. fk.CARET .."发送答复，需手搓JSON除非有特殊提示，注意无合法性检测\n"
    .. fk.GRAY .."  -------------------------------\n" .. fk.RST
		.. fk.BLUE .."  room/r".. fk.CARET .."查看房间概况\n"
		.. fk.BLUE .."  player/p".. fk.CARET .."查看玩家概况，参数为玩家id默认1\n"
		.. fk.BLUE .."  skill/s".. fk.CARET .."查看技能描述\n"
  )
end

local reply_processors = {
  ["AskForGeneral"] = function(args)
    return json.encode(args)
  end,
  ["AskForSkillInvoke"] = function(args)
    local ret = args[1]
    if ret == 'n' or ret == 'N' then
      return ''
    end
    return '1'
  end,
}
local cmd_reply = function(args)
  if #args == 0 then return "" end
  local room = Fk:currentRoom()
  local player = room:getPlayerById(1)
  local command = player.ai_data.command
  if reply_processors[command] then
    return reply_processors[command](args)
  else
    return args[1]
  end
end

local function getRoleStr(str)
  if str == "lord" then
    return fk.RED .. fk.BOLD .. "主" .. fk.RST
  elseif str == "loyalist" then
    return fk.YELLOW .. fk.BOLD .. "忠" .. fk.RST
  elseif str == "rebel" then
    return fk.GREEN .. fk.BOLD .. "反" .. fk.RST
  elseif str == "renegade" then
    return fk.BLUE .. fk.BOLD .. "内" .. fk.RST
  end
end

local function writeCardList(cidlist)
  for _, id in ipairs(cidlist) do
    io.write(trcid(id))
    io.write(" ")
  end
end

local cmd_room = function()
  local room = Fk:currentRoom()
  if not room.players[3].shield then return end
  printf("第%d轮 牌堆剩%d张", room.tag['RoundCount'], #room.draw_pile)
  print("\n玩家列表：")
  for _, p in ipairs(room.players) do
    io.write(string.format("%s%d ID=%d %s %s %d|%d/%d %d牌",
      p.id == 1 and "*" or "", p.seat, p.id, getRoleStr(p.role),
      (p.dead and fk.GRAY or fk.GREEN) .. Fk:translate(p.general) .. fk.RST,
      p.shield, p.hp, p.maxHp, #p.player_cards[Player.Hand]))
    if #p.player_cards[Player.Equip] > 0 then io.write(" 有装备") end
    if #p.player_cards[Player.Judge] > 0 then io.write(" 有判定") end
    io.write("\n")
  end
  --[[
  print("\n摸牌堆：")
  writeCardList(room.draw_pile)
  print("\n弃牌堆：")
  writeCardList(room.discard_pile)
  print("\nVoid牌堆：")
  writeCardList(room.void)
  --]]
end

local cmd_player = function(args)
  local room = Fk:currentRoom()
  if #args == 0 then table.insert(args, "1") end
  for _, sid in ipairs(args) do
    local p = room:getPlayerById(tonumber(sid))
    io.write(fk.BOLD .. tostring(p) .. fk.RST .. " " .. getRoleStr(p.role))
    if p.general and p.general ~= "" then
      io.write(" " .. tr(p.general))
    else
      io.write("\n"); return
    end
    if p.deputyGeneral and p.deputyGeneral ~= "" then
      io.write("/" .. tr(p.deputyGeneral))
    end
    io.write(string.format(" HP: %d|%d/%d", p.shield, p.hp, p.maxHp))
    if p.dead then io.write(" 已死亡") end
    io.write("\n")

    if #p.player_cards[Player.Hand] > 0 then
      io.write(string.format("共%d张手牌: ", #p.player_cards[Player.Hand]))
      writeCardList(p.player_cards[Player.Hand])
      io.write("\n")
    else
      print("没有手牌")
    end
    if #p.player_cards[Player.Equip] > 0 then
      io.write("装备区内的牌: ")
      writeCardList(p.player_cards[Player.Equip])
      io.write("\n")
    end
    if #p.player_cards[Player.Judge] > 0 then
      io.write("判定区内的牌: ")
      writeCardList(p.player_cards[Player.Judge])
      io.write("\n")
    end

    io.write("技能：")
    for _, s in ipairs(p.player_skills) do
      if s.visible then io.write(tr(s.name) .. " ") end
    end
    io.write("\n")
  end
end

local cmd_skill = function(args)
  for _, s in ipairs(args) do
    print(fk.BOLD .. tr(s) .. fk.RST)
    print(colorConvert(Fk:getDescription(s)))
  end
end

local cmd_card = function(args)
  for _, s in ipairs(args) do
    local cid = tonumber(s)
    if not cid then return end
    local c = Fk:getCardById(cid, true)
    if not c then return end
    print(fk.BOLD .. trcid(cid) .. fk.RST)
    print(colorConvert(Fk:getDescription(c.name)))
  end
end

local command_table = {
  help = cmd_help, h = cmd_help,
  dbg = function() dbg() end,

  reply = cmd_reply, rp = cmd_reply,
  room = cmd_room, r = cmd_room,
  player = cmd_player, p = cmd_player,
  skill = cmd_skill, s = cmd_skill,
  card = cmd_card, c = cmd_card,
}
local last_cmd = "help"

function ServerPlayer:waitForReply()
  -- dbg() 时的便利变量
  local room = RoomInstance
  local logic = room.logic
  local player = room:getPlayerById(self.id)
  if self.id == 1 then
    while true do
      io.write(string.char(27) .. "[95m(FkTest) " .. fk.RST)
      io.flush()
      local line = io.read()
      if line == nil then break end -- Ctrl-D
      local args = line:split(" ")
      for i = #args, 1, -1 do
        if args[i] == "" then table.remove(args, i) end
      end

      local command = table.remove(args, 1)
      if command == nil then
        command = last_cmd
      else
        last_cmd = command
      end
      local f = command_table[command]
      if f then
        local ret = f(args)
        if ret then return ret end
      elseif command then
        print(fk.RED .. "unknown command '" .. command .. "'" .. fk.RST)
      end
    end
  end
  return ""
end
function ServerPlayer:doNotify(cmd, j)
  if self.id ~= 100 then
    return
  end
  if cmd == "GameLog" then
    print(parseMsg(json.decode(j)))
  elseif cmd == "MoveCards" then
    local raw_moves = json.decode(j)
    local separated = separateMoves(raw_moves)
    local merged = mergeMoves(separated)
    for _, move in ipairs(merged) do
      sendMoveCardLog(move)
    end
  elseif cmd == "GameOver" then
    print(cmd, j)
  end
end
function ServerPlayer:busy() return self._busy end
function ServerPlayer:setBusy(b) self._busy = b end
function ServerPlayer:thinking() return self._thinking end
function ServerPlayer:setThinking(t) self._thinking = t end
function ServerPlayer:emitKick()
  self.state = fk.Player_Offline
end
function ServerPlayer:getGameData()
  return {[0]=0,0,0,0,at=function(t,k)return t[k]end}
end

return ServerPlayer

