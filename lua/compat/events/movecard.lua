--- 将新数据改为牢数据
function MoveCardsData:toLegacy()
  local ret = table.simpleClone(rawget(self, "_data"))
  ret.from = ret.from and ret.from.id
  ret.to = ret.to and ret.to.id
  ret.proposer = ret.proposer and ret.proposer.id

  if ret.visiblePlayers then
    ret.visiblePlayers = table.map(ret.visiblePlayers, Util.IdMapper)
  end

  return ret
end

--- 将牢数据改为新数据
function MoveCardsData:loadLegacy(data)
  for k, v in pairs(data) do
    if table.contains({"from", "to", "proposer"}, k) then
      self[k] = Fk:currentRoom():getPlayerById(v)
    elseif table.contains({"visiblePlayers"}, k) then
      if type(v) == "number" then
        v = {v}
      end
      self[k] = table.map(v, Util.Id2PlayerMapper)
    else
      self[k] = v
    end
  end
end
