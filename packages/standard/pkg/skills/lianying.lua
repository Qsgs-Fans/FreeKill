local lianying = fk.CreateSkill({
  name = "lianying",
})

lianying:addEffect(fk.AfterCardsMove, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if not (player:hasSkill(lianying.name) and player:isKongcheng()) then return end
    for _, move in ipairs(data) do
      if move.from == player then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerHand then
            return true
          end
        end
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, lianying.name)
  end,
})

local AI = Fk.Ltk.AI
lianying:addAI(AI.reuse("biyue", AI.InvokeStrategy))

return lianying
