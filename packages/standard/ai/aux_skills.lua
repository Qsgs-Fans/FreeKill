SmartAI:setSkillAI("discard_skill", {
  think = function(self, ai)
    verbose(1, "正思考discard_skill")
    local skill = self.skill
    local cancel_val = skill.cancelable and 0 or -100000
    for cards in self:searchCardSelections(ai) do
      verbose(1, "discard_skill打算弃置%s", json.encode(cards))
      return ai:doOKButton()
    end
  end,
})
