TestExppattern = {
  testUtil = function()
    local table1 = {1, 3, 5, 8}
    local table2 = {2, 3, 5, 7}
    p(table1)
    p(table2)
    p(table.connect(table1, table2))
    p(table1)
    p(table2)
    p(table.connectIfNeed(table1, table2))
    p(table1)
    p(table2)
    p(table.slice(table1,3,4))
    p(table.slice(table1,1,6))
    p(table.slice(table1,-2,-1))
  end,

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
    lu.assertTrue(Exppattern:Parse(".|.|.|.|.|trick"):matchExp("lightning"))
    lu.assertFalse(Exppattern:Parse(".|.|.|.|.|delayed_trick"):matchExp("savage_assault"))
  end,

  testMatchNeg = function()
    lu.assertError(function() Exppattern:Parse("^(a,|1)") end)
    local not_nul = Exppattern:Parse("^nullification")
    local not_slash_jink = Exppattern:Parse("^(slash,jink)")
    local not_basic = Exppattern:Parse(".|.|.|.|.|^basic")
    local not_black = Exppattern:Parse(".|.|^(spade,club)")
    local slash_jink = Exppattern:Parse("slash,jink")
    local no_slash_jink = Exppattern:Parse("^(slash,jink)|.|.|.|.|basic")
    local slash = Fk:cloneCard("slash")

    lu.assertFalse(not_nul:matchExp("nullification"))
    lu.assertTrue(not_basic:matchExp("nullification"))
    lu.assertFalse(not_slash_jink:matchExp("jink"))
    lu.assertTrue(not_nul:match(slash))
    lu.assertFalse(not_slash_jink:match(slash))
    lu.assertFalse(not_basic:match(slash))
    lu.assertTrue(not_nul:matchExp("peach"))
    lu.assertFalse(not_basic:matchExp(no_slash_jink))
    lu.assertTrue(not_slash_jink:matchExp(not_basic))
    lu.assertFalse(slash_jink:matchExp(not_slash_jink))
    lu.assertFalse(not_black:matchExp("slash|A~Q|spade"))
    lu.assertTrue(not_black:matchExp("vine|10|^club"))
  end,

}
