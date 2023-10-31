-- aux_skill的AI文件。aux_skill的重量级程度无需多说。
-- 这个文件说是第二个smart_ai.lua也不为过。

-- discard_skill: 弃牌相关AI
-----------------------------

--- 弃牌相关判定函数的表。键为技能名，值为原型如下的函数。
---@type table<string, fun(self: SmartAI, min_num: number, num: number, include_equip: bool, cancelable: bool, pattern: string, prompt: string): integer[]|nil>
fk.ai_discard = {}

local default_discard = function(self, min_num, num, include_equip, cancelable, pattern, prompt)
  if cancelable then return nil end
  local flag = "h"
  if include_equip then
    flag = "he"
  end
  local ret = {}
  local cards = self.player:getCardIds(flag)
  for _, cid in ipairs(cards) do
    table.insert(ret, cid)
    if #ret >= min_num then
      break
    end
  end
  return ret
end

fk.ai_use_skill["discard_skill"] = function(self, prompt, cancelable, data)
  local ask = fk.ai_discard[data.skillName]
  if ask == nil and not cancelable then
    ask = default_discard
  end

  local ret
  if ask then
    ret = ask(self, data.min_num, data.num, data.include_equip, cancelable, data.pattern, prompt)
  end
  if ret == nil or #ret < data.min_num then return nil end

  return {
    card = json.encode {
      skill = "discard_skill",
      subcards = ask
    }
  }
end

-- choose_players_skill: 选人相关AI
-------------------------------------

---@class ChoosePlayersReply
---@field cardId integer|nil
---@field targets integer[]

--- 选人相关判定函数的表。键为技能名，值为原型如下的函数。
---@type table<string, fun(self: SmartAI, targets: integer[], min_num: number, num: number, cancelable: bool): ChoosePlayersReply|nil>
fk.ai_choose_players = {}

fk.ai_use_skill["choose_players_skill"] = function(self, prompt, cancelable, data)
  local ask = fk.ai_choose_players[data.skillName]
  local ret
  if ask then
    ret = ask(self, data.targets, data.min_num, data.num, cancelable)
  end
  if ret then
    return {
      card = json.encode {
        skill = "discard_skill",
        subcards = { ret.cardId }
      },
      targets = ret.targets,
    }
  end
end
