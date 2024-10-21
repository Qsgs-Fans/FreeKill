local PopupBox = require 'ui_emu.popupbox'
local common = require 'ui_emu.common'
local CardItem = common.CardItem
-- 过河拆桥、顺手牵羊使用的选卡包

---@class ChooseCardBox: PopupBox
local ChooseCardBox = PopupBox:subclass("ChooseCardBox")

function ChooseCardBox:initialize(player)
  self.room = Fk:currentRoom()
  self.player = player
end

-- 打开qml框后的初始化，对应request打开qml框的操作
---@param data any @ 数据
function ChooseCardBox:setup(data)
  for _, cid in ipairs(data.cards) do
    self:addItem(CardItem:new(self, cid))
  end
end

-- 父场景将UI应有的变化传至此处
-- 需要实现各种合法性检验，决定需要变更状态的UI，并最终将变更反馈给真实的界面
---@param elemType string @ 元素类型
---@param id any @ 元素ID
---@param action any @ 动作
---@param data any @ 数据
---@return { [string]: Item[] }
function ChooseCardBox:update(elemType, id, action, data)
  -- 返回自己的变化
  return self.change
end

return PopupBox
