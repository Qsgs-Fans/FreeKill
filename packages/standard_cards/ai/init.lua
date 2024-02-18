-- TODO: 合法性的方便函数
-- TODO: 关于如何选择多个目标
-- TODO: 关于装备牌

-- 基本牌：杀，闪，桃

---@param from ServerPlayer
---@param to ServerPlayer
---@param card Card
local function tgtValidator(from, to, card)
  return not from:prohibitUse(card) and
    not from:isProhibited(to, card) and
    true -- feasible
end

local function justUse(self, card_name, extra_data)
  local slashes = self:getCards(card_name, "use", extra_data)
  if #slashes == 0 then return nil end

  return self:buildUseReply(slashes[1].id)
end

---@param self SmartAI
---@param card_name string
local function useToEnemy(self, card_name, extra_data)
  local slashes = self:getCards(card_name, "use", extra_data)
  if #slashes == 0 then return nil end

  -- TODO: 目标合法性
  local targets = {}
  if self.enemies[1] then
    table.insert(targets, self.enemies[1].id)
  else
    return nil
  end

  return self:buildUseReply(slashes[1].id, targets)
end

fk.ai_use_card["slash"] = function(self, pattern, prompt, cancelable, extra_data)
  return useToEnemy(self, "slash", extra_data)
end

fk.ai_use_card["jink"] = function(self, pattern, prompt, cancelable, extra_data)
  return justUse(self, "jink", extra_data)
end

fk.ai_use_card["peach"] = function(self, _, _, _, extra_data)
  local cards = self:getCards("peach", "use", extra_data)
  if #cards == 0 then return nil end

  return self:buildUseReply(cards[1].id)
end

-- 自救见军争卡牌AI
fk.ai_use_card["#AskForPeaches"] = function(self)
  local room = self.room
  local deathEvent = room.logic:getCurrentEvent()
  local data = deathEvent.data[1] ---@type DyingStruct

  -- TODO: 关于救不回来、神关羽之类的更复杂逻辑
  -- TODO: 这些逻辑感觉不能写死在此函数里面，得想出更加多样的办法
  if self:isFriend(room:getPlayerById(data.who)) then
    return fk.ai_use_card["peach"](self)
  end
  return nil
end

fk.ai_use_card["dismantlement"] = function(self, pattern, prompt, cancelable, extra_data)
  return useToEnemy(self, "dismantlement", extra_data)
end

fk.ai_use_card["snatch"] = function(self, pattern, prompt, cancelable, extra_data)
  return useToEnemy(self, "snatch", extra_data)
end

fk.ai_use_card["duel"] = function(self, pattern, prompt, cancelable, extra_data)
  return useToEnemy(self, "duel", extra_data)
end

fk.ai_use_card["ex_nihilo"] = function(self, pattern, prompt, cancelable, extra_data)
  return justUse(self, "ex_nihilo", extra_data)
end

fk.ai_use_card["indulgence"] = function(self, pattern, prompt, cancelable, extra_data)
  return useToEnemy(self, "indulgence", extra_data)
end
