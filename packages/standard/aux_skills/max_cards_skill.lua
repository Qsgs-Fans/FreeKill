local maxCardsSkill = fk.CreateSkill{
  name = "max_cards_skill",
}

maxCardsSkill:addEffect("maxcards", {
  global = true,
  correct_func = function(self, player)
    local function getMark(markname)
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
    return
      getMark(MarkEnum.AddMaxCards) -
      getMark(MarkEnum.MinusMaxCards)
  end,
})

return maxCardsSkill
