-- 针对 core/util.lua 的一些测试用例

TestUtil = {}

function TestUtil:testMisc()
  lu.assertError(function()
    Util.DummyTable.a = 4
  end)
end

function TestUtil:testString()
  lu.assertIs("He" + "is", "Heis")
  local utf8string = "刘备，天下枭雄"
  lu.assertEquals(utf8string:len(), 7)
  lu.assertEquals(utf8string:rawlen(), 21)
  lu.assertEquals(#utf8string, 21)

  local s = "gfsdf%kj.\\ts4!!,34':"
  lu.assertFalse(s:endsWith("%"))
end

function TestUtil:testTable()
  local t = {1, 2, 5}
  table.insertIfNeed(t, 2)
  lu.assertEquals(t, {1, 2, 5})
end
