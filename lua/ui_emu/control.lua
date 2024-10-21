-- 对应QtQuick.Controls里面的组件 或者相对应的
-- 以后可能还有更多需要模拟的组件吧
local base = require 'ui_emu.base'
local Item = base.Item

---@class Button: SelectableItem
local Button = Item:subclass("Button")

return {
  Button = Button,
}
