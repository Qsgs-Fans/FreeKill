-- SPDX-License-Identifier: GPL-3.0-or-later
-- Trust AI
---@class TrustAI: AI
local TrustAI = AI:subclass("TrustAI")

local trust_cb = {}

function TrustAI:initialize(player)
  AI.initialize(self, player)
  self.cb_table = trust_cb
<<<<<<< HEAD
=======
  self.player = player
  self.room = RoomInstance or ClientInstance

  fk.ai_role[player.id] = "neutral"
  fk.roleValue[player.id] = {
    lord = 0,
    loyalist = 0,
    rebel = 0,
    renegade = 0
  }
  self:updatePlayers()
end

function TrustAI:isRolePredictable()
  return self.room.settings.gameMode ~= "aaa_role_mode"
end

local function aliveRoles(room)
  fk.alive_roles = {
    lord = 0,
    loyalist = 0,
    rebel = 0,
    renegade = 0
  }
  for _, ap in ipairs(room:getAllPlayers(false)) do
    fk.alive_roles[ap.role] = 0
  end
  for _, ap in ipairs(room:getAlivePlayers(false)) do
    fk.alive_roles[ap.role] = fk.alive_roles[ap.role] + 1
  end
  return fk.alive_roles
end

function TrustAI:objectiveLevel(to)
  if self.player.id == to.id then
    return -2
  elseif #self.room:getAlivePlayers(false) < 3 then
    return 5
  end
  local ars = aliveRoles(self.room)
  if self:isRolePredictable() then
    fk.ai_role[self.player.id] = self.role
    fk.roleValue[self.player.id][self.role] = 666
    if self.role == "renegade" then
      fk.explicit_renegade = true
    end
    for _, p in ipairs(self.room:getAlivePlayers()) do
      if
          p.role == self.role or p.role == "lord" and self.role == "loyalist" or
          p.role == "loyalist" and self.role == "lord"
      then
        table.insert(self.friends, p)
        if p.id ~= self.player.id then
          table.insert(self.friends_noself, p)
        end
      else
        table.insert(self.enemies, p)
      end
    end
  elseif self.role == "renegade" then
    if to.role == "lord" then
      return -1
    elseif ars.rebel < 1 then
      return 4
    elseif fk.ai_role[to.id] == "loyalist" then
      return ars.lord + ars.loyalist - ars.rebel
    elseif fk.ai_role[to.id] == "rebel" then
      local r = ars.rebel - ars.lord + ars.loyalist
      if r >= 0 then
        return 3
      else
        return r
      end
    end
  elseif self.role == "lord" or self.role == "loyalist" then
    if fk.ai_role[to.id] == "rebel" then
      return 5
    elseif to.role == "lord" then
      return -2
    elseif ars.rebel < 1 then
      if self.role == "lord" then
        return fk.explicit_renegade and fk.ai_role[to.id] == "renegade" and 4 or to.hp > 1 and 2 or 0
      elseif fk.explicit_renegade then
        return fk.ai_role[to.id] == "renegade" and 4 or -1
      else
        return 3
      end
    elseif fk.ai_role[to.id] == "loyalist" then
      return -2
    elseif fk.ai_role[to.id] == "renegade" then
      local r = ars.lord + ars.loyalist - ars.rebel
      if r <= 0 then
        return r
      else
        return 3
      end
    end
  elseif self.role == "rebel" then
    if to.role == "lord" then
      return 5
    elseif fk.ai_role[to.id] == "loyalist" then
      return 4
    elseif fk.ai_role[to.id] == "rebel" then
      return -2
    elseif fk.ai_role[to.id] == "renegade" then
      local r = ars.rebel - ars.lord + ars.loyalist
      if r > 0 then
        return 1
      else
        return r
      end
    end
  end
  return 0
end

function TrustAI:updatePlayers(update)
  self.role = self.player.role
  local neutrality = {}
  self.enemies = {}
  self.friends = {}
  self.friends_noself = {}

  local aps = self.room:getAlivePlayers()
  local function compare_func(a, b)
    local v1 = fk.roleValue[a.id].rebel
    local v2 = fk.roleValue[b.id].rebel
    if v1 == v2 then
      v1 = fk.roleValue[a.id].renegade
      v2 = fk.roleValue[b.id].renegade
    end
    return v1 > v2
  end
  table.sort(aps, compare_func)
  fk.explicit_renegade = false
  local ars = aliveRoles(self.room)
  local rebel, renegade, loyalist = 0, 0, 0
  for _, ap in ipairs(aps) do
    if ap.role == "lord" then
      fk.ai_role[ap.id] = "loyalist"
    elseif fk.roleValue[ap.id].rebel > 50 and ars.rebel > rebel then
      rebel = rebel + 1
      fk.ai_role[ap.id] = "rebel"
    elseif fk.roleValue[ap.id].renegade > 50 and ars.renegade > renegade then
      renegade = renegade + 1
      fk.ai_role[ap.id] = "renegade"
      fk.explicit_renegade = fk.roleValue[ap.id].renegade > 100
    elseif fk.roleValue[ap.id].rebel < -50 and ars.loyalist > loyalist then
      loyalist = loyalist + 1
      fk.ai_role[ap.id] = "loyalist"
    else
      fk.ai_role[ap.id] = "neutral"
    end
  end

  for n, p in ipairs(self.room:getAlivePlayers(false)) do
    n = self:objectiveLevel(p)
    if n < 0 then
      table.insert(self.friends, p)
      if p.id ~= self.player.id then
        table.insert(self.friends_noself, p)
      end
    elseif n > 0 then
      table.insert(self.enemies, p)
    else
      table.insert(neutrality, p)
    end
  end
  self:assignValue()
  --[[
		if self.enemies<1 and #neutrality>0
		and#self.toUse<3 and self:getOverflow()>0
		then
		function compare_func(a,b)
			return sgs.getDefense(a)<sgs.getDefense(b)
		end
		table.sort(neutrality,compare_func)
		table.insert(self.enemies,neutrality[1])
		end-]]
end

local function updateIntention(player, to, intention)
  if player.id == to.id then
    return
  elseif player.role == "lord" then
    fk.roleValue[to.id].rebel = fk.roleValue[to.id].rebel + intention * (200 - fk.roleValue[to.id].rebel) / 200
  else
    if to.role == "lord" or fk.ai_role[to.id] == "loyalist" then
      fk.roleValue[player.id].rebel = fk.roleValue[player.id].rebel +
          intention * (200 - fk.roleValue[player.id].rebel) / 200
    elseif fk.ai_role[to.id] == "rebel" then
      fk.roleValue[player.id].rebel = fk.roleValue[player.id].rebel -
          intention * (fk.roleValue[player.id].rebel + 200) / 200
    end
    if fk.roleValue[player.id].rebel < 0 and intention > 0 or fk.roleValue[player.id].rebel > 0 and intention < 0 then
      fk.roleValue[player.id].renegade = fk.roleValue[player.id].renegade +
          intention * (100 - fk.roleValue[player.id].renegade) / 200
    end
    local aps = player.room:getAlivePlayers()
    local function compare_func(a, b)
      local v1 = fk.roleValue[a.id].rebel
      local v2 = fk.roleValue[b.id].rebel
      if v1 == v2 then
        v1 = fk.roleValue[a.id].renegade
        v2 = fk.roleValue[b.id].renegade
      end
      return v1 > v2
    end
    table.sort(aps, compare_func)
    fk.explicit_renegade = false
    local ars = aliveRoles(player.room)
    local rebel, renegade, loyalist = 0, 0, 0
    for _, ap in ipairs(aps) do
      if ap.role == "lord" then
        fk.ai_role[ap.id] = "loyalist"
      elseif fk.roleValue[ap.id].rebel > 50 and ars.rebel > rebel then
        rebel = rebel + 1
        fk.ai_role[ap.id] = "rebel"
      elseif fk.roleValue[ap.id].renegade > 50 and ars.renegade > renegade then
        renegade = renegade + 1
        fk.ai_role[ap.id] = "renegade"
        fk.explicit_renegade = fk.roleValue[ap.id].renegade > 100
      elseif fk.roleValue[ap.id].rebel < -50 and ars.loyalist > loyalist then
        loyalist = loyalist + 1
        fk.ai_role[ap.id] = "loyalist"
      else
        fk.ai_role[ap.id] = "neutral"
      end
    end
    fk.qWarning(
      player.general ..
      " " ..
      intention ..
      " " ..
      fk.ai_role[player.id] ..
      " rebelValue:" .. fk.roleValue[player.id].rebel .. " renegadeValue:" .. fk.roleValue[player.id].renegade
    ) --]]
  end
end

function TrustAI:filterEvent(event, player, data)
  if event == fk.TargetSpecified then
    local callback = fk.ai_card[data.card.name]
    callback = callback and callback.intention
    if type(callback) == "function" then
      for _, p in ipairs(TargetGroup:getRealTargets(data.tos)) do
        p = self.room:getPlayerById(p)
        local intention = callback(p.ai, data.card, self.room:getPlayerById(data.from))
        if type(intention) == "number" then
          updateIntention(self.room:getPlayerById(data.from), p, intention)
        end
      end
    elseif type(callback) == "number" then
      for _, p in ipairs(TargetGroup:getRealTargets(data.tos)) do
        p = self.room:getPlayerById(p)
        updateIntention(self.room:getPlayerById(data.from), p, callback)
      end
    end
  elseif event == fk.StartJudge then
    fk.trick_judge[data.reason] = data.pattern
  elseif event == fk.AfterCardsMove then
  end
end

function TrustAI:isWeak(player, getAP)
  player = player or self.player
  if type(player) == "number" then
    player = self.room:getPlayerById(player)
  end
  return player.hp < 2 or player.hp <= 2 and #player:getCardIds("&h") <= 2
end

function TrustAI:isFriend(pid, tid)
  if tid then
    local bt = self:isFriend(pid)
    return bt ~= nil and bt == self:isFriend(tid)
  end
  if type(pid) == "number" then
    pid = self.room:getPlayerById(pid)
  end
  local ve = self:objectiveLevel(pid)
  if ve < 0 then
    return true
  elseif ve > 0 then
    return false
  end
end

function TrustAI:isEnemie(pid, tid)
  if tid then
    local bt = self:isFriend(pid)
    return bt ~= nil and bt ~= self:isFriend(tid)
  end
  if type(pid) == "number" then
    pid = self.room:getPlayerById(pid)
  end
  local ve = self:objectiveLevel(pid)
  if ve > 0 then
    return true
  elseif ve < 0 then
    return false
  end
end

function TrustAI:eventData(game_event)
  local event = self.room.logic:getCurrentEvent():findParent(GameEvent[game_event], true)
  return event and event.data[1]
end

for _, n in ipairs(FileIO.ls("packages")) do
  if FileIO.isDir("packages/" .. n) and FileIO.exists("packages/" .. n .. "/" .. n .. "_ai.lua") then
    dofile("packages/" .. n .. "/" .. n .. "_ai.lua")
  end
end
-- 加载两次拓展是为了能够引用，例如属性杀的使用直接套入普通杀的使用
for _, n in ipairs(FileIO.ls("packages")) do
  if FileIO.isDir("packages/" .. n) and FileIO.exists("packages/" .. n .. "/" .. n .. "_ai.lua") then
    dofile("packages/" .. n .. "/" .. n .. "_ai.lua")
  end
>>>>>>> 79d3213cc0aa996c9072ae5696e387a9bda210d8
end

return TrustAI
