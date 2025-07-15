local skill = fk.CreateSkill {
  name = "#dilu_skill",
  tags = { Skill.Compulsory },
  attached_equip = "dilu",
}

skill:addEffect("distance", {
  correct_func = function(self, from, to)
    if to:hasSkill(skill.name) then
      return 1
    end
  end,
})

skill:addTest(function (room, me)
  local card = room:printCard("dilu")
  local origin = table.map(room:getOtherPlayers(me), function(other) return other:distanceTo(me) end)
  FkTest.runInRoom(function ()
    room:useCard{
      card = card,
      from = me,
      tos = { me },
    }
  end)
  for i, other in ipairs(room:getOtherPlayers(me)) do
    lu.assertEquals(other:distanceTo(me), origin[i] + 1)
  end
end)

return skill
