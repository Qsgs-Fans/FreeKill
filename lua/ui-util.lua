-- SPDX-License-Identifier: GPL-3.0-or-later

-- 主动技/视为技用。
-- 能创造一个简单的组件供UI使用。

-- 前端的应答/修改最终会被保存到xxx.data中。
-- 同时，这些应答也会被上传到服务器中。

local UI = {}

-- ComboBox: 一个按钮，点击后会显示类似askForChoice的框供选择
-- 可以赋值的属性有：
-- * choices: string[] 类型，保存着可选项，会被前端翻译
-- * default: string，默认的选项，默认为choices的第一个
-- * detailed: bool，为真的话送详细信息
-- * all_choices: string[] 类型，保存着所有选项，会被前端翻译
UI.ComboBox = function(spec)
  -- assert(type(spec.choices) == "table", "Choices is not a table")
  -- assert(#spec.choices > 0, "Choices is empty")
  spec.choices = type(spec.choices) == "table" and spec.choices or Util.DummyTable
  spec.default = spec.default or spec.choices[1]
  spec.detailed = spec.detailed or false
  spec.all_choices = type(spec.all_choices) == "table" and spec.all_choices or spec.choices
  spec.type = "combo"
  return spec
end

-- Spin: 一个能用两侧加减号调整某些数值的组件，见于奇谋等技能
-- 可以赋值的属性有：
-- * from: 最小值
-- * to: 最大值
-- * default: 默认值 默认为最小的
UI.Spin = function(spec)
  assert(spec.from <= spec.to)
  spec.type = "spin"
  return spec
end

return UI
