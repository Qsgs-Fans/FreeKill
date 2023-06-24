TestExppattern = {
  testMatchExp = function()
    local exp1 = Exppattern:Parse("slash,jink")
    lu.assertTrue(exp1:matchExp("peack,jink"))
  end,

  testEasyMatchCard = function()
    local exp1 = Exppattern:Parse("slash,jink")
    local exp2 = Exppattern:Parse("peach,jink")
    local slash = Fk:cloneCard("slash")
    lu.assertTrue(exp1:match(slash))
    lu.assertFalse(exp2:match(slash))
  end,

  testMatchWithType = function()
    local exp3 = Exppattern:Parse(".|.|.|.|.|normal_trick")
    lu.assertFalse(exp3:matchExp("slash,jink"))
    lu.assertTrue(exp3:matchExp("peach,ex_nihilo"))

    local basic = Exppattern:Parse(".|.|.|.|.|basic")
    lu.assertFalse(basic:matchExp("nullification"))
    lu.assertTrue(basic:matchExp("slash,vine"))
    lu.assertTrue(Exppattern:Parse(".|.|.|.|.|armor"):matchExp("slash,vine"))
  end,
}
