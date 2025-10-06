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

return choosePlayersToMoveCardInBoardSkill
