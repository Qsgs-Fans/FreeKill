local choosePlayersToMoveCardInBoardSkill = fk.CreateSkill{
  name = "choose_players_to_move_card_in_board",
}

choosePlayersToMoveCardInBoardSkill:addEffect("active", {
  target_num = 2,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected, cards)
    if #selected > 0 then
      return selected[1]:canMoveCardsInBoardTo(to_select, self.flag, self.excludeIds) and
        table.contains(self.tos, to_select)
    end
    if not table.contains(self.froms, to_select) then return false end

    local fromAreas = { Player.Equip, Player.Judge }
    if self.flag == "e" then
      fromAreas = { Player.Equip }
    elseif self.flag == "j" then
      fromAreas = { Player.Judge }
    end

    return #table.filter(to_select:getCardIds(fromAreas), function(id)
      return not table.contains((type(self.excludeIds) == "table" and self.excludeIds or {}), id)
    end) > 0
  end,
})

-- choosePlayersToMoveCardInBoardSkill:addAI(Fk.Ltk.AI.newActiveStrategy {
--   think = function(self, ai)
--     local data = ai.data[4]
--     local orig = Fk.skills[data.skillName] or choosePlayersToMoveCardInBoardSkill
--     local strategy = ai:findStrategyOfSkill(Fk.Ltk.AI.MoveBoardStrategy, orig.name)
--     if not strategy then
--       strategy = ai:findStrategyOfSkill(Fk.Ltk.AI.MoveBoardStrategy, choosePlayersToMoveCardInBoardSkill.name)
--       ---@cast strategy -nil
--     end

--     local from, from_benefit = strategy:chooseMoveFrom(ai)
--     local to, to_benefit = strategy:chooseMoveTo(ai)
--     if from and to then
--       return { nil, { from, to } }, (from_benefit + to_benefit) or 0
--     end
--   end,
-- })

-- choosePlayersToMoveCardInBoardSkill:addAI(Fk.Ltk.AI.newMoveBoardStrategy {
--   choose_move_from = function(self, ai)
--     local data = ai.data[4] -- extra_data
--     local available_players = ai:getEnabledTargets()

--     if ai.data[3] --[[ cancelable ]] then return nil, 0 end

--     table.shuffle(available_players) -- 随机选择以视高深莫测
--     return table.slice(available_players, 1, 1)[1].id, 0
--   end,
--   choose_move_to = function(self, ai)
--     local data = ai.data[4] -- extra_data
--     local available_players = ai:getEnabledTargets()

--     if ai.data[3] --[[ cancelable ]] then return nil, 0 end

--     table.shuffle(available_players) -- 随机选择以视高深莫测
--     return table.slice(available_players, 1, 1)[1].id, 0
--   end,
-- })

return choosePlayersToMoveCardInBoardSkill
