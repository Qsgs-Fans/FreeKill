-- 针对 core/util.lua 的一些测试用例

-- 总感觉没啥好测试的

TestUtil = {
  testMisc = function()
    lu.assertError(function()
      Util.DummyTable.a = 4
    end)
  end,

  testString = function()
    lu.assertIs("He" + "is", "Heis")
    local utf8string = "刘备，天下枭雄"
    lu.assertEquals(utf8string:len(), 7)
    lu.assertEquals(utf8string:rawlen(), 21)
    lu.assertEquals(#utf8string, 21)

    local s = "gfsdf%kj.\\ts4!!,34':"
    lu.assertFalse(s:endsWith("%"))
  end,

  testTable = function()
    local t = {1, 2, 5}
    table.insertIfNeed(t, 2)
    lu.assertEquals(t, {1, 2, 5})
  end,
}
