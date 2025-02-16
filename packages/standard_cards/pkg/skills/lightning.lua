local skill = fk.CreateSkill {
  name = "lightning_skill",
}

skill:addEffect("active", {
  prompt = "#lightning_skill",
  mod_target_filter = Util.TrueFunc,
  can_use = Util.CanUseToSelf,
  on_use = function(self, room, use)
    ---@cast use -SkillUseData
    if #use.tos == 0 then
      use:addTarget(use.from)
    end
  end,
  on_effect = function(self, room, effect)
    local to = effect.to
    local judge = {
      who = to,
      reason = "lightning",
      pattern = ".|2~9|spade",
    }
    room:judge(judge)
    local result = judge.card
    if result.suit == Card.Spade and result.number >= 2 and result.number <= 9 then
      room:damage{
        to = to,
        damage = 3,
        card = effect.card,
        damageType = Fk:getDamageNature(fk.ThunderDamage) and fk.ThunderDamage or fk.NormalDamage,
        skillName = self.name,
      }

      room:moveCards{
        ids = room:getSubcardsByRule(effect.card, { Card.Processing }),
        toArea = Card.DiscardPile,
        moveReason = fk.ReasonUse,
      }
    else
      self:onNullified(room, effect)
    end
  end,
  on_nullified = function(self, room, effect)
    local to = effect.to
    local nextp = to
    repeat
      nextp = nextp:getNextAlive(true)
      if nextp == to then
        if nextp:isProhibited(nextp, effect.card) then
          room:moveCards{
            ids = room:getSubcardsByRule(effect.card, { Card.Processing }),
            toArea = Card.DiscardPile,
            moveReason = fk.ReasonPut,
          }
          return
        end
        break
      end
    until not nextp:hasDelayedTrick("lightning") and not nextp:isProhibited(nextp, effect.card)


    if effect.card:isVirtual() then
      nextp:addVirtualEquip(effect.card)
    end

    room:moveCards{
      ids = room:getSubcardsByRule(effect.card, { Card.Processing }),
      to = nextp,
      toArea = Card.PlayerJudge,
      moveReason = fk.ReasonPut,
    }
  end,
})

return skill
