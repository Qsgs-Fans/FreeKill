-- 主动技/视为技用。
-- 能创造一个简单的组件供UI使用。

-- 前端的应答/修改最终会被保存到xxx.data中。

local UI = {}

-- ComboBox: 下拉对话框。
--
--   +-------------+
--   | choices   V |
--   +-------------+
--       | choice1 |
--       +---------+
--       | choice2 |
--       +---------+
--
-- 可以赋值的属性有：
-- * choices: string[] 类型，保存着可选项，会被前端翻译
-- * default: string，默认的选项，默认为choices的第一个
UI.ComboBox = function(spec)
  assert(type(spec.choices) == "table", "Choices is not a table")
  assert(#spec.choices > 0, "Choices is empty")
  spec.default = spec.default or spec.choices[1]
  spec.type = "combo"
  return spec
end

return UI
