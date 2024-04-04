-- aux_skill的AI文件。aux_skill的重量级程度无需多说。
-- 这个文件说是第二个smart_ai.lua也不为过。

-- discard_skill: 弃牌相关AI
-----------------------------

--- 弃牌相关判定函数的表。键为技能名，值为原型如下的函数。
---@type table<string, fun(self: SmartAI, min_num: number, num: number, include_equip?: boolean, cancelable?: boolean, pattern: string, prompt: string): integer[]?>
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

fk.ai_active_skill["discard_skill"] = function(self, prompt, cancelable, data)
  local ret = self:callFromTable(fk.ai_discard, not cancelable and default_discard, data.skillName,
    self, data.min_num, data.num, data.include_equip, cancelable, data.pattern, prompt)

  if ret == nil or #ret < data.min_num then return nil end

  return self:buildUseReply { skill = "discard_skill", subcards = ret }
end

-- choose_players_skill: 选人相关AI
-------------------------------------

---@class ChoosePlayersReply
---@field cardId? integer
---@field targets integer[]

--- 选人相关判定函数的表。键为技能名，值为原型如下的函数。
---@type table<string, fun(self: SmartAI, targets: integer[], min_num: number, num: number, cancelable?: boolean): ChoosePlayersReply?>
fk.ai_choose_players = {}

fk.ai_active_skill["choose_players_skill"] = function(self, prompt, cancelable, data)
  local ret = self:callFromTable(fk.ai_choose_players, nil, data.skillName,
    self, data.targets, data.min_num, data.num, cancelable)

  if ret then
    return self:buildUseReply({ skill = "choose_players_skill", subcards = { ret.cardId } }, ret.targets)
  end
end
