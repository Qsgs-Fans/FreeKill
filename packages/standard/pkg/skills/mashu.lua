local mashu = fk.CreateSkill{
  name = "mashu",
  frequency = Skill.Compulsory,
}

mashu:addEffect("distance", {
  correct_func = function(self, from, to)
    if from:hasSkill(mashu.name) then
      return -1
    end
  end,
})

mashu:addTest(function(room, me)
  local origin = table.map(room:getOtherPlayers(me), function(other) return me:distanceTo(other) end)

  FkTest.runInRoom(function()
    room:handleAddLoseSkills(me, "mashu")
  end)

  for i, other in ipairs(room:getOtherPlayers(me)) do
    lu.assertEquals(me:distanceTo(other), math.max(origin[i] - 1, 1))
  end
end)

return mashu
