local choosePlayersToMoveCardInBoardSkill = fk.CreateSkill{
  name = "choose_players_to_move_card_in_board",
}

choosePlayersToMoveCardInBoardSkill:addEffect("active", {
  target_num = 2,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected, cards)
    local target = Fk:currentRoom():getPlayerById(to_select)
    if #selected > 0 then
      return Fk:currentRoom():getPlayerById(selected[1]):canMoveCardsInBoardTo(target, self.flag, self.excludeIds)
    end

    local fromAreas = { Player.Equip, Player.Judge }
    if self.flag == "e" then
      fromAreas = { Player.Equip }
    elseif self.flag == "j" then
      fromAreas = { Player.Judge }
    end

    return #table.filter(target:getCardIds(fromAreas), function(id)
      return not table.contains((type(self.excludeIds) == "table" and self.excludeIds or {}), id)
    end) > 0
  end,
})

return choosePlayersToMoveCardInBoardSkill
