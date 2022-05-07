---@class ServerPlayer : Player
---@field serverplayer fk.ServerPlayer
---@field room Room
---@field next ServerPlayer
---@field request_data string
---@field client_reply string
---@field default_reply string
---@field reply_ready boolean
---@field phases Phase[]
---@field phase_state table[]
---@field phase_index integer
local ServerPlayer = Player:subclass("ServerPlayer")

function ServerPlayer:initialize(_self)
  Player.initialize(self)
  self.serverplayer = _self
  self.id = _self:getId()
  self.state = _self:getStateString()
  self.room = nil

  self.next = nil

  -- Below are for doBroadcastRequest
  self.request_data = ""
  self.client_reply = ""
  self.default_reply = ""
  self.reply_ready = false
  self.phases = {}
end

---@param command string
---@param jsonData string
function ServerPlayer:doNotify(command, jsonData)
  self.serverplayer:doNotify(command, jsonData)
end

--- Send a request to client, and allow client to reply within *timeout* seconds.
---
--- *timeout* must not be negative. If nil, room.timeout is used.
---@param command string
---@param jsonData string
---@param timeout integer
function ServerPlayer:doRequest(command, jsonData, timeout)
  timeout = timeout or self.room.timeout
  self.client_reply = ""
  self.reply_ready = false
  self.serverplayer:doRequest(command, jsonData, timeout)
end

--- Wait for at most *timeout* seconds for reply from client.
---
--- If *timeout* is negative or **nil**, the function will wait forever until get reply.
---@param timeout integer @ seconds to wait
---@return string @ JSON data
function ServerPlayer:waitForReply(timeout)
  local result = ""
  if timeout == nil then
    result = self.serverplayer:waitForReply()
  else
    result = self.serverplayer:waitForReply(timeout)
  end
  self.request_data = ""
  self.client_reply = result
  if result ~= "" then self.reply_ready = true end
  return result
end

function ServerPlayer:isAlive()
  return self.dead == false
end

function ServerPlayer:getNextAlive()
  if #self.room.alive_players == 0 then
    return self
  end

  local ret = self.next
  while ret.dead do
    ret = ret.next
  end
  return ret
end

function ServerPlayer:turnOver()
  self.faceup = not self.faceup
  self.room:broadcastProperty(self, "faceup")

  -- TODO: log
  self.room.logic:trigger(fk.TurnedOver, self)
end

---@param from_phase Phase
---@param to_phase Phase
function ServerPlayer:changePhase(from_phase, to_phase)
  local room = self.room
  local logic = room.logic
  self.phase = Player.PhaseNone

  local phase_change = {
    from = from_phase,
    to = to_phase
  }

  local skip = logic:trigger(fk.EventPhaseChanging, self, phase_change)
  if skip and to_phase ~= Player.NotActive then
    self.phase = from_phase
    return true
  end

  self.phase = to_phase
  room:notifyProperty(self, self, "phase")

  if #self.phases > 0 then 
    table.remove(self.phases, 1)
  end

  if not logic:trigger(fk.EventPhaseStart, self) then
    if self.phase ~= Player.NotActive then
      logic:trigger(fk.EventPhaseProceeding, self)
    end
  end

  if self.phase ~= Player.NotActive then
    logic:trigger(fk.EventPhaseEnd, self)
  end

  return false
end

---@param phase_table Phase[]
function ServerPlayer:play(phase_table)
  phase_table = phase_table or {}
  if #phase_table > 0 then
    if not table.contains(phase_table, Player.NotActive) then
      table.insert(phase_table, Player.NotActive)
    end
  else
    phase_table = {
      Player.RoundStart, Player.Start,
      Player.Judge, Player.Draw, Player.Play, Player.Discard,
      Player.Finish, Player.NotActive,
    }
  end

  self.phases = phase_table
  self.phase_state = {}

  local phases = self.phases
  local phase_state = self.phase_state
  local room = self.room

  for i = 1, #phases do
    phase_state[i] = {
      phase = phases[i],
      skipped = false
    }
  end

  for i = 1, #phases do
    if self.dead then
      self:changePhase(self.phase, Player.NotActive)
      break
    end

    self.phase_index = i
    local phase_change = {
      from = self.phase,
      to = phases[i]
    }

    local logic = self.room.logic
    self.phase = Player.PhaseNone

    local skip = logic:trigger(fk.EventPhaseChanging, self, phase_change)
    phases[i] = phase_change.to
    phase_state[i].phase = phases[i]

    self.phase = phases[i]
    room:notifyProperty(self, self, "phase")

    local cancel_skip = true
    if phases[i] ~= Player.NotActive and (phase_state[i].skipped or skip) then
      cancel_skip = logic:trigger(fk.EventPhaseSkipping, self)
    end

    if (not skip) or (cancel_skip) then
      if not logic:trigger(fk.EventPhaseStart, self) then
        if self.phase ~= Player.NotActive then
          logic:trigger(fk.EventPhaseProceeding, self)
        end
      end

      if self.phase ~= Player.NotActive then
        logic:trigger(fk.EventPhaseEnd, self)
      else break end
    end
  end
end

return ServerPlayer
