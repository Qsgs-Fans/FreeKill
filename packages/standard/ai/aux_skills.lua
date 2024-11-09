SmartAI:setSkillAI("discard_skill", {
  choose_targets = function(_, ai)
    return ai:doOKButton()
  end,
})

SmartAI:setSkillAI("choose_cards_skill", {
  choose_targets = function(_, ai)
    return ai:doOKButton()
  end,
})
