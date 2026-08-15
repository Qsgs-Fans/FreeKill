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
  spec.default = spec.default or spec.from
  return spec
end

-- CardNameBox：用于选牌名的组件，和UI.ComboBox差不多。一般用于泛转化技
-- 必输参数：可选牌名choices；可输参数：全部牌名all_choices
UI.CardNameBox = function(spec)
  spec.choices = type(spec.choices) == "table" and spec.choices or Util.DummyTable
  if type(spec.all_choices) == "table" then
    if #spec.all_choices == 0 or type(spec.all_choices[1]) ~= "table" then
      spec.all_choices = {spec.all_choices}
    end
  else
    spec.all_choices = {spec.choices}
  end
  spec.default = spec.default and spec.default or spec.choices[1]
  spec.type = "cardname"
  return spec
end

-- 多选框
-- 可以赋值的属性有：
-- * choices: string[] 类型，保存可选项
-- * cancelable: bool 是否可取消
-- * detailed: bool 为真的话送详细信息
-- * all_choices: string[] 类型，保存所有选项
UI.CheckBox = function(spec)
  spec.choices = type(spec.choices) == "table" and spec.choices or {}
  spec.all_choices = type(spec.all_choices) == "table" and spec.all_choices or spec.choices
  spec.detailed = spec.detailed or false
  spec.cancelable = spec.cancelable or false
  spec.type = "checkbox"
  return spec
end

---@class OptionBoxParams
---@field options string[]
---@field all_options? string[]
---@field single? boolean
---@field direct_send? boolean 危险参数，按下一个选项会直接返回值，并且强制启用single，建议配合refresh_interaction一起使用
---@field min_num? integer
---@field max_num? integer
-- * options: string[] 类型，保存可选项
-- * all_options: string[] 类型，保存所有选项
-- * cancelable: bool 是否可取消
---@param spec OptionBoxParams
---@return OptionBoxParams
UI.OptionBox = function (spec)
  if spec.type then error("can't define type first!") end

  spec.options = type(spec.options) == "table" and spec.options or {}
  spec.all_options = type(spec.all_options) == "table" and spec.all_options or spec.options
  spec.direct_send = spec.direct_send or false
  spec.single = (spec.single == nil or spec.direct_send) and true

  spec.min_num = spec.min_num or 1
  spec.max_num = spec.max_num or 1
  if spec.min_num > spec.max_num then
    spec.max_num = spec.min_num
  end

  spec.type = "optionbox"
  return spec
end

-- spec可以填个ids: integer[]或者card_names: string[]显示一些卡牌。
UI.ExpandItems = function(spec)
  spec.type = "expandItems"
  return spec
end

return UI
