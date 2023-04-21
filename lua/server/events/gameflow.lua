-- SPDX-License-Identifier: GPL-3.0-or-later

GameEvent.functions[GameEvent.DrawInitial] = function(self)
  local room = self.room
  for _, p in ipairs(room.alive_players) do
    room.logic:trigger(fk.DrawInitialCards, p, { num = 4 })
  end
end

GameEvent.functions[GameEvent.Round] = function(self)
  local room = self.room
  local logic = room.logic
  local p

  logic:trigger(fk.RoundStart, room.current)

  repeat
    p = room.current
    GameEvent(GameEvent.Turn):exec()
    if room.game_finished then break end
    room.current = room.current:getNextAlive()
  until p.seat > p:getNextAlive().seat

  logic:trigger(fk.RoundEnd, p)
end

GameEvent.functions[GameEvent.Turn] = function(self)
  local room = self.room
  room.logic:trigger(fk.TurnStart, room.current)

  local player = room.current
  if not player.faceup then
    player:turnOver()
  elseif not player.dead then
    player:play()
  end
end
