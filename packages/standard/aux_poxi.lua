-- SPDX-License-Identifier: GPL-3.0-or-later

Fk:addPoxiMethod{
  name = "AskForCardsChosen",
  card_filter = function(to_select, selected, data, extra_data)
    if #selected >= extra_data.max then return end
    if extra_data.pattern then
      if extra_data.visible_data and extra_data.visible_data[string.format("%i", to_select)] == false then
        return false
      end
      return Exppattern:Parse(extra_data.pattern):match(Fk:getCardById(to_select))
    end
    return true
  end,
  feasible = function(selected, data, extra_data)
    return #selected >= extra_data.min and #selected <= extra_data.max
  end,
  prompt = function(data, extra_data)
    if extra_data.prompt then
      return extra_data.prompt
    else
      local ret = Fk:translate("#AskForChooseCards")
      ret = ret:gsub("%%1", Fk:translate(extra_data.skillName or "AskForCardsChosen"))
      ret = ret:gsub("%%2", math.floor(extra_data.min)) -- floor to avoid float number
      ret = ret:gsub("%%3", math.floor(extra_data.max))
      return ret .. ":" ..extra_data.to
    end
  end,
  default_choice = function(data, extra_data)
    local ret = {}
    for _, pile in ipairs(data) do
      local cards = pile[2]
      local lim = extra_data.min - #ret
      if #cards > lim then
        table.insertTable(ret, table.random(cards, lim))
        break
      end
      table.insertTable(ret, cards)
    end
    return ret
  end
}
