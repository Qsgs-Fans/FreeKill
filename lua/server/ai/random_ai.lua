---@class RandomAI: AI
local RandomAI = AI:subclass("RandomAI")

local random_cb = {}

random_cb.AskForUseActiveSkill = function(self, jsonData) end
random_cb.AskForGeneral = function(self, jsonData)
  return json.encode{table.random(json.decode(jsonData))}
end

random_cb.AskForCardChosen = function(self, jsonData) end
random_cb.AskForChoice = function(self, jsonData)
  local choices = json.decode(jsonData)[1]
  return table.random(choices)
end

random_cb.AskForSkillInvoke = function(self, jsonData)
  return table.random{"1", ""}
end

random_cb.AskForGuanxing = function(self, jsonData) end
random_cb.AskForUseCard = function(self, jsonData) end
random_cb.AskForResponseCard = function(self, jsonData) end

---@param self RandomAI
random_cb.PlayCard = function(self, jsonData)
  local cards = table.map(self.player:getCardIds(Player.Hand),
    function(id) return Fk:getCardById(id) end)

  while #cards > 0 do
    local card = table.random(cards)
    local skill = card.skill
    if skill:canUse(self.player) then
      local selected_targets = {}
      local max_try_time = 1000
      while not skill:feasible(selected_targets) do
        if max_try_time <= 0 then
          break
        end
        local avail_targets = table.filter(self.room:getAlivePlayers(),
          function(p) return skill:targetFilter(p.id, {}) end)
        break
      end
      if skill:feasible(selected_targets) then
        local ret = json.encode{
          card = card.id,
          targets = {},
        }
        print(ret)
        return ret
      else
        table.removeOne(cards, card)
      end
    else
      table.removeOne(cards, card)
    end
  end
  return ""
end

function RandomAI:initialize(player)
  AI.initialize(self, player)
  self.cb_table = random_cb
end

return RandomAI
