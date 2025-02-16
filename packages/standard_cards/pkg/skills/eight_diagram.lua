local skill = fk.CreateSkill {
  name = "#eight_diagram_skill",
  attached_equip = "eight_diagram",
}

local eight_diagram_on_use = function (self, event, target, player, data)
    local room = player.room
    local judgeData = {
      who = player,
      reason = self.name,
      pattern = ".|.|heart,diamond",
    }
    room:judge(judgeData)

    if judgeData.card.color == Card.Red then
      if event:isInstanceOf(fk.AskForCardUse) then
        data.result = {
          from = player,
          card = Fk:cloneCard("jink"),
          tos = {},
        }
        data.result.card.skillName = "eight_diagram"

        if data.eventData then
          data.result.toCard = data.eventData.toCard
          data.result.responseToEvent = data.eventData.responseToEvent
        end
      else
        data.result = Fk:cloneCard("jink")
        data.result.skillName = "eight_diagram"
      end

      return true
    end
  end
skill:addEffect(fk.AskForCardUse, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and
      (data.cardName == "jink" or (data.pattern and Exppattern:Parse(data.pattern):matchExp("jink|0|nosuit|none"))) and
      not player:prohibitUse(Fk:cloneCard("jink"))
  end,
  on_use = eight_diagram_on_use,
})
skill:addEffect(fk.AskForCardResponse, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and
      (data.cardName == "jink" or (data.pattern and Exppattern:Parse(data.pattern):matchExp("jink|0|nosuit|none"))) and
      not player:prohibitResponse(Fk:cloneCard("jink"))
  end,
  on_use = eight_diagram_on_use,
})

---[[
skill:addTest(function(room, me)
  local eight_diagram = room:printCard("eight_diagram")
  local comp2 = room.players[2]

  FkTest.setNextReplies(me, { "1" })
  FkTest.runInRoom(function()
    room:useCard {
      from = me,
      tos = { me },
      card = eight_diagram,
    }
    room:moveCardTo(room:printCard("slash", Card.Heart), Card.DrawPile)
    room:useCard {
      from = comp2,
      tos = { me },
      card = Fk:cloneCard("slash"),
    }
  end)
  lu.assertEquals(me.hp, 4)
  FkTest.setNextReplies(me, { "1", "1", "" })
  FkTest.runInRoom(function()
    room:moveCardTo(room:printCard("slash", Card.Diamond), Card.DrawPile)
    room:useCard {
      from = comp2,
      tos = { me },
      card = Fk:cloneCard("archery_attack"),
    }
    room:moveCardTo(room:printCard("slash", Card.Spade), Card.DrawPile)
    room:useCard {
      from = comp2,
      tos = { me },
      card = Fk:cloneCard("slash"),
    }
  end)
  lu.assertEquals(me.hp, 3)
end)
--]]

return skill
