local base = require 'ui_emu.base'
local control = require 'ui_emu.control'
local Scene = base.Scene

-- 一种模拟具体qml框的处理机构
-- 具体是什么东西全靠继承子类处理

-- 理论上来说，这就是一个小scene
-- 会向其父场景传输其应有的变化
-- 同理，UI改变也由父场景传输至这里

---@class PopupBox: Scene
local PopupBox = Scene:subclass("PopupBox")

-- 打开qml框后的初始化，对应request打开qml框的操作
function PopupBox:initialize(parent, data)
  Scene.initialize(self, parent)
  self.data = data
  self.change = {}
end

-- 模拟一次UI交互，修改相关item的属性即可
-- 同时修改自己parent的changeData
function PopupBox:update(elemType, id, newData)
  local item = self.items[elemType][id]
  local changed = item:setData(newData)
  local changeData = self.change
  if changed and changeData then
    changeData[elemType] = changeData[elemType] or {}
    table.insert(changeData[elemType], item:toData())
  end
end

-- 由父RequestHandler调用，用以将本qml变化传至父RequestHandler
-- 调用者需要维护changeData，确保传给UI的数据最少
function PopupBox:notifyUI()
  if not ClientInstance then return nil end
  self.parent.change["_type"] = self.class.name
  ClientInstance:notifyUI("UpdateRequestUI", self.parent.change)
end

return PopupBox
