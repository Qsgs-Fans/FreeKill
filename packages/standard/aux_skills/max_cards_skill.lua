local maxCardsSkill = fk.CreateSkill{
  name = "max_cards_skill",
}

local function getMark(player, markname)
  local v = 0
  for mark, value in pairs(player.mark) do
    if mark == markname then
      v = v + value
    elseif mark:startsWith(markname .. "-") then
      for _, suffix in ipairs(MarkEnum.TempMarkSuffix) do
        if mark:find(suffix, 1, true) then
          v = v + value
          break
        end
      end
    end
  end
  return v
end

maxCardsSkill:addEffect("maxcards", {
  global = true,
  correct_func = function(self, player)
    local base = 0
    if player.role == "lord" then
      base = base - #table.filter(Fk:currentRoom().alive_players, function (p)
        return p.role == "rebel_chief"
      end)
    end
    return base + getMark(player, MarkEnum.AddMaxCards) - getMark(player, MarkEnum.MinusMaxCards)
  end,
})

return maxCardsSkill
