local spin_skill = fk.CreateSkill({
  name = "spin_skill",
})

spin_skill:addEffect("active", {
  card_num = 0,
  target_num = 0,
  interaction = function(self, player)
    return UI.Spin { from = self.min, to = self.max }
  end,
})

spin_skill:addAI(Fk.Ltk.AI.newActiveStrategy {
  think = function(self, ai)
    local data = ai.data[4]
    local orig = Fk.skills[data.skillName] or spin_skill
    local strategy = ai:findStrategyOfSkill(Fk.Ltk.AI.NumberStrategy, orig.name)
    if not strategy then
      strategy = ai:findStrategyOfSkill(Fk.Ltk.AI.NumberStrategy, spin_skill.name)
      ---@cast strategy -nil
    end

    local interaction, interaction_benefit = strategy:chooseInteraction(ai)
    if interaction then
      return { nil, nil, interaction }, interaction_benefit or 0
    end
  end,
})

spin_skill:addAI(Fk.Ltk.AI.newNumberStrategy {
  choose_interaction = function (self, ai)
    local data = ai.data[4] -- extra_data

    if ai.data[3] --[[ cancelable ]] then return nil, 0 end

    local value = math.random(data.min, data.max)
    return value, 0
  end
})

return spin_skill
