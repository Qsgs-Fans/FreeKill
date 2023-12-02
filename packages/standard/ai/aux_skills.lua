-- aux_skill的AI文件。aux_skill的重量级程度无需多说。
-- 这个文件说是第二个smart_ai.lua也不为过。

-- discard_skill: 弃牌相关AI
-----------------------------

--- 弃牌相关判定函数的表。键为技能名，值为原型如下的函数。
---@type table<string, fun(self: SmartAI, min_num: number, num: number, include_equip: bool, cancelable: bool, pattern: string, prompt: string): any>
fk.ai_discard = {}

--- 请求弃置
---
---由skillName进行下一级的决策，只需要在下一级里返回需要弃置的卡牌id表就行
fk.ai_use_skill["discard_skill"] = function(self, prompt, cancelable, data)
  local ask = fk.ai_discard[data.skillName]
  self:assignValue()
  if type(ask) == "function" then
    ask = ask(self, data.min_num, data.num, data.include_equip, cancelable, data.pattern, prompt)
  end
  if type(ask) ~= "table" and not cancelable then
    local flag = "h"
    if data.include_equip then
      flag = "he"
    end
    ask = {}
    local cards = table.map(self.player:getCardIds(flag), function(id)
        return Fk:getCardById(id)
      end
    )
    self:sortValue(cards)
    for _, c in ipairs(cards) do
      table.insert(ask, c.id)
      if #ask >= data.min_num then
        break
      end
    end
  end
  if type(ask) == "table" and #ask >= data.min_num then
    self.use_id = json.encode {
      skill = data.skillName,
      subcards = ask
    }
  end
end

-- choose_players_skill: 选人相关AI
-------------------------------------

--- 选人相关判定函数的表。键为技能名，值为原型如下的函数。
---@type table<string, fun(self: SmartAI, targets: integer[], min_num: number, num: number, cancelable: bool)>
fk.ai_choose_players = {}

--- 请求选择目标
---
---由skillName进行下一级的决策，只需要在下一级里给self.use_tos添加角色id为目标就行
fk.ai_use_skill["choose_players_skill"] = function(self, prompt, cancelable, data)
  local ask = fk.ai_choose_players[data.skillName]
  if type(ask) == "function" then
    ask(self, data.targets, data.min_num, data.num, cancelable)
  end
  if #self.use_tos > 0 then
    if self.use_id then
      self.use_id = json.encode {
        skill = data.skillName,
        subcards = self.use_id
      }
    else
      self.use_id = json.encode {
        skill = data.skillName,
        subcards = {}
      }
    end
  end
end
