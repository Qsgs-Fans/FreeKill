-- 便于测试的封装

--- 在测试房间内添加技能
---@param player ServerPlayer
---@param skill_name string
FkTest.RunAddSkills = function (player, skill_name)
  FkTest.runInRoom(function ()
    player.room:handleAddLoseSkills(player, skill_name)
  end)
end

--- 设置第n次询问时断点，用于setRoomBreakpoint
---@param n integer
---@return function
FkTest.CreateClosure = function(n)
  local i = 0
  return function()
    i = i + 1
    return i == n
  end
end

--- 回复使用/打出卡牌
---@param card Card
---@param targets? ServerPlayer[]
FkTest.ReplyCard = function (card, targets)
  return {
    card = card.id,
    targets = targets and table.map(targets, Util.IdMapper) or {},
  }
end

--- 回复使用技能
---@param skill_name string
---@param targets? ServerPlayer[]
---@param cards? integer[]
FkTest.ReplyUseSkill = function (skill_name, targets, cards)
  return {
    card = { skill = skill_name, subcards = cards or {} },
    targets = targets and table.map(targets, Util.IdMapper) or {},
  }
end

--- 回复askToChoosePlayers
---@param targets ServerPlayer[]
FkTest.ReplyChoosePlayer = function (targets)
  return FkTest.ReplyUseSkill("choose_players_skill", targets)
end

--- 回复askToCards等，选择自己的牌
---@param cards integer[]
FkTest.ReplyChooseCards = function (cards)
  return FkTest.ReplyUseSkill("choose_cards_skill", nil, cards)
end

--- 回复askToDiscard等，弃置自己的牌
---@param cards integer[]
FkTest.ReplyDiscard = function (cards)
  return FkTest.ReplyUseSkill("discard_skill", nil, cards)
end

--- 回复askToChooseCardsAndPlayers等
---@param players ServerPlayer[]
---@param cards integer[]
FkTest.ReplyChooseCardAndPlayers = function (players, cards)
  return FkTest.ReplyUseSkill("ex__choose_skill", players, cards)
end
