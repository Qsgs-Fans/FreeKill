local qianxun = fk.CreateSkill{
  name = "qianxun",
  tags = { Skill.Compulsory },
}

qianxun:addEffect("prohibit", {
  is_prohibited = function(self, from, to, card)
    if to:hasSkill(qianxun.name) and card then
      return table.contains({ "indulgence", "snatch" }, card.trueName)
    end
  end,
})

return qianxun
