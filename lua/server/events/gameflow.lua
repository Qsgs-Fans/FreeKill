GameEvent.functions[GameEvent.DrawInitial] = function(self)
  local room = self.room
  for _, p in ipairs(room.alive_players) do
    room.logic:trigger(fk.DrawInitialCards, p, { num = 4 })
  end
end

GameEvent.functions[GameEvent.Turn] = function(self)
  local room = self.room
  room.logic:trigger(fk.TurnStart, room.current)
end
