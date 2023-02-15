local fkp_extensions = require "packages.test.test"
local extension = fkp_extensions[1]

local test_filter = fk.CreateFilterSkill{
  name = "test_filter",
  card_filter = function(self, card)
    return true
  end,
  view_as = function(self, card)
    return Fk:cloneCard("ex_nihilo", card.suit, card.number)
  end,
}
local test2 = General(extension, "mouxusheng", "wu", 4)
test2:addSkill(test_filter)

Fk:loadTranslationTable{
  ["test"] = "测试",
  ["test_filter"] = "破军",
  ["mouxusheng"] = "谋徐盛",
}

return fkp_extensions
