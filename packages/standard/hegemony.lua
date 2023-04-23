local heg

---@class HegLogic: GameLogic
local HegLogic = {}

function HegLogic:assignRoles()
  local room = self.room
  for _, p in ipairs(room.players) do
    p.role_shown = true
    p.role = "hidden"
    room:broadcastProperty(p, "role")
  end

  -- for adjustSeats
  room.players[1].role = "lord"
end

function HegLogic:chooseGenerals()
  local room = self.room
  local generalNum = math.max(room.settings.generalNum, 6)

  local lord = room:getLord()
  room.current = lord
  lord.role = "hidden"

  local nonlord = room.players
  local generals = Fk:getGeneralsRandomly(#nonlord * generalNum)
  -- table.shuffle(generals)
  for _, p in ipairs(nonlord) do
    local arg = { map = table.map }
    for i = 1, generalNum do
      table.insert(arg, table.remove(generals, 1))
    end
    table.sort(arg, function(a, b) return a.kingdom > b.kingdom end)

    for idx, _ in ipairs(arg) do
      if arg[idx].kingdom == arg[idx + 1].kingdom then
        p.default_reply = { arg[idx].name, arg[idx + 1].name }
        break
      end
    end

    arg = arg:map(function(g) return g.name end)
    p.request_data = json.encode({ arg, 2, true })
  end

  room:notifyMoveFocus(nonlord, "AskForGeneral")
  room:doBroadcastRequest("AskForGeneral", nonlord)
  for _, p in ipairs(nonlord) do
    local general, deputy
    if p.general == "" and p.reply_ready then
      local generals = json.decode(p.client_reply)
      general = generals[1]
      deputy = generals[2]
      room:setPlayerGeneral(p, general, true)
      room:setDeputyGeneral(p, deputy)
    else
      general = p.default_reply[1]
      deputy = p.default_reply[2]
    end

    p:setMark("heg_general", general)
    p:setMark("heg_deputy", deputy)
    p:doNotify("SetPlayerMark", json.encode{ p.id, "heg_general", general})
    p:doNotify("SetPlayerMark", json.encode{ p.id, "heg_deputy", deputy})

    room:setPlayerGeneral(p, "anjiang", true)
    room:setDeputyGeneral(p, "anjiang")

    p.default_reply = ""
  end
end

local heg_choose_generals = function(self)
end

local heg_getlogic = function()
  local h = GameLogic:subclass("HegLogic")
  for k, v in pairs(HegLogic) do
    h[k] = v
  end
  return h
end

heg = fk.CreateGameMode{
  name = "heg_mode",
  minPlayer = 2,
  maxPlayer = 8,
  -- rule = m_2v2_rule,
  logic = heg_getlogic,
}

Fk:loadTranslationTable{
  ["heg_mode"] = "国战经典版",
}

return heg
