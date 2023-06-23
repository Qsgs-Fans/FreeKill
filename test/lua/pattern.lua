local exp1 = Exppattern:Parse("slash,jink")
local exp2 = Exppattern:Parse("peach,jink")
local exp3 = Exppattern:Parse(".|.|.|.|.|trick")
local exp4 = Exppattern:Parse("peach,ex_nihilo")

local slash = Fk:cloneCard("slash")

TestExppattern = {
  testMatchExp = function()
    assert(exp1:matchExp(exp2))
  end,

  testEasyMatchCard = function()
    assert(exp1:match(slash))
    assert(not exp2:match(slash))
  end,

  testMatchWithType = function()
    assert(not exp3:matchExp(exp1))
    assert(exp3:matchExp(exp4))
  end,
}
