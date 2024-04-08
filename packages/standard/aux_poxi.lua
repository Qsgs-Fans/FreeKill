-- SPDX-License-Identifier: GPL-3.0-or-later

Fk:addPoxiMethod{
  name = "AskForCardsChosen",
  card_filter = function(to_select, selected, data, extra_data)
    return #selected < extra_data.max
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
      ret = ret:gsub("%%2", Fk:translate(extra_data.min))
      ret = ret:gsub("%%3", Fk:translate(extra_data.max))
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
