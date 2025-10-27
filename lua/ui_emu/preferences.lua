-- 游戏模式配置选项可能会用到的模拟ui组件
-- 为什么要取名W啊？
local W = {}

local function convertSpec(spec)
  local needcopy
  spec._children = {}

  for i = 1, #spec do
    table.insert(spec._children, spec[i])
    needcopy = needcopy or spec[i]._needcopy
    spec[i] = nil
  end

  if not needcopy then
    for _, v in pairs(spec) do
      if type(v) == "function" then
        needcopy = true
        break
      end
    end
  end

  if needcopy then
    spec._needcopy = needcopy
  end

  return spec
end

W.toQmlData = function(spec, settings)
  if not spec._needcopy then
    return spec
  end

  local ret = {
    _qml = spec._qml,
    _needcopy = true,
    _children = {},
  }

  for _, v in ipairs(spec._children) do
    table.insert(ret._children, W.toQmlData(v, settings))
  end

  for k, v in pairs(spec) do
    if type(k) == "string" and not k:startsWith("_") then
      if type(v) == "function" then
        ret[k] = v(settings)
      else
        ret[k] = v
      end
    end
  end

  return ret
end

---@class W.CommonSpec
---@field title string 主提示文本（翻译之前
---@field subTitle string? 副提示文本（翻译之前 默认是 "help: " .. title
---@field _qml QmlComponent?
---@field _needcopy any
---@field _children any

---@class W.PreferenceGroupSpec: W.CommonSpec
---@field title string? 主提示文本（翻译之前

---@param spec W.PreferenceGroupSpec
W.PreferenceGroup = function(spec)
  spec._qml = {
    uri = "Fk.Widgets",
    name = "PreferenceGroup",
  }

  return convertSpec(spec)
end

--[[
---@class W.ActionSpec : W.CommonSpec

---@param spec W.CommonSpec
W.ActionRow = function(spec)
  spec._qml = {
    uri = "Fk.Widgets",
    name = "ActionRow",
  }

  return convertSpec(spec)
end

W.ButtonRow = function(spec)
  spec._qml = {
    uri = "Fk.Widgets",
    name = "ButtonRow",
  }

  return convertSpec(spec)
end
--]]

---@class W.CommonValueSpec : W.CommonSpec
---@field _settingsKey string 你这个value对应到settings的哪个key

---@param spec W.CommonValueSpec
W.SwitchRow = function(spec)
  spec._qml = {
    uri = "Fk.Widgets",
    name = "SwitchRow",
  }

  return convertSpec(spec)
end

---@class W.ComboRowSpec : W.CommonValueSpec
---@field model string[]

---@param spec W.ComboRowSpec
W.ComboRow = function(spec)
  spec._qml = {
    uri = "Fk.Widgets",
    name = "TranslatedComboRow",
  }

  return convertSpec(spec)
end

---@class W.SpinRowSpec : W.CommonValueSpec
---@field from integer
---@field to integer

---@param spec W.SpinRowSpec
W.SpinRow = function(spec)
  spec._qml = {
    uri = "Fk.Widgets",
    name = "SpinRow",
  }

  return convertSpec(spec)
end

--[[
W.SliderRow = function(spec)
  spec._qml = {
    uri = "Fk.Widgets",
    name = "SliderRow",
  }

  return convertSpec(spec)
end
--]]

---@param spec W.CommonValueSpec
W.EntryRow = function(spec)
  spec._qml = {
    uri = "Fk.Widgets",
    name = "EntryRow",
  }

  return convertSpec(spec)
end

---@class W.PageButtonSpec
---@field name string
---@field iconUrl string
---@field popup boolean?
---@field qml QmlComponent

return W
