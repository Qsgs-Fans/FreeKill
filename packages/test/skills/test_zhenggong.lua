local zhenggong = fk.CreateSkill{
  name = "test_zhenggong",
  tags = { Skill.Compulsory },
}

Fk:loadTranslationTable{
  ["test_zhenggong"] = "迅测",
  [":test_zhenggong"] = "锁定技，首轮开始时，你执行额外的回合。",
  ["$test_zhenggong"] = "今疑兵之计，已搓敌兵心胆，其安敢侵近！",
}

zhenggong:addEffect(fk.RoundStart, {
  anim_type = "negative",
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(zhenggong.name) and player.room:getBanner("RoundCount") == 1
  end,
  on_use = function(self, event, target, player, data)
    player:gainAnExtraTurn()
  end,
})

return zhenggong
