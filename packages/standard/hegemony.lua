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

    p:setMark("__heg_general", general)
    p:setMark("__heg_deputy", deputy)
    p:doNotify("SetPlayerMark", json.encode{ p.id, "__heg_general", general})
    p:doNotify("SetPlayerMark", json.encode{ p.id, "__heg_deputy", deputy})

    room:setPlayerGeneral(p, "anjiang", true)
    room:setDeputyGeneral(p, "anjiang")

    p.default_reply = ""
  end
end

function HegLogic:broadcastGeneral()
  local room = self.room
  local players = room.players

  for _, p in ipairs(players) do
    assert(p.general ~= "")
    local general = Fk.generals[p:getMark("__heg_general")]
    local deputy = Fk.generals[p:getMark("__heg_deputy")]
    p.maxHp = math.floor((deputy.maxHp + general.maxHp) / 2)
    p.hp = math.floor((deputy.hp + general.hp) / 2)
    -- p.shield = math.min(general.shield + deputy.shield, 5)
    p.shield = 0
    -- TODO: setup AI here

    room:broadcastProperty(p, "general")
    room:broadcastProperty(p, "deputyGeneral")
    room:broadcastProperty(p, "maxHp")
    room:broadcastProperty(p, "hp")
     room:broadcastProperty(p, "shield")
  end
end

function HegLogic:attachSkillToPlayers()
  local room = self.room
  local players = room.players

  room:handleAddLoseSkills(players[1], "#_heg_invalid", nil, false, true)

  local addHegSkills = function(player, skillName)
    local skill = Fk.skills[skillName]
    if skill.lordSkill and (player.role ~= "lord" or #room.players < 5) then
      return
    end

    -- room:handleAddLoseSkills(player, skillName, nil, false)
    player:doNotify("AddSkill", json.encode{ player.id, skillName})
  end

  for _, p in ipairs(room.alive_players) do
    local general = Fk.generals[p:getMark("__heg_general")]
    local skills = general.skills
    for _, s in ipairs(skills) do
      addHegSkills(p, s.name)
    end
    for _, sname in ipairs(general.other_skills) do
      addHegSkills(p, sname)
    end

    local deputy = Fk.generals[p:getMark("__heg_deputy")]
    if deputy then
      skills = deputy.skills
      for _, s in ipairs(skills) do
        addHegSkills(p, s.name)
      end
      for _, sname in ipairs(deputy.other_skills) do
        addHegSkills(p, sname)
      end
    end
  end
end

local heg_getlogic = function()
  local h = GameLogic:subclass("HegLogic")
  for k, v in pairs(HegLogic) do
    h[k] = v
  end
  return h
end

local heg_invalid = fk.CreateInvaliditySkill{
  name = "#_heg_invalid",
  invalidity_func = function(self, player, skill)
  end,
}

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
