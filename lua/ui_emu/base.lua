-- 模拟一套UI操作，并在具体子类中实现相应操作逻辑。分为UI组件和UI场景两种类。
-- 在客户端与Qml直接同步，在服务端中用于AI。

-- 模拟UI组件。最基本的属性为enabled，表示是否可以进行交互。
-- 注意在编写逻辑时不要直接修改Item的属性。用scene:update。
---@class Item: Object
---@field public parent Scene
---@field public enabled boolean
---@field public id string | integer
local Item = class("Item")

---@parant scene Scene
function Item:initialize(scene, id)
  self.parent = scene
  self.enabled = false
  self.id = id
end

function Item:toData()
  return {
    enabled = self.enabled,
    id = self.id,
  }
end

---@return boolean 是否发生改变
function Item:setData(newData)
  local changed
  for k, v in pairs(newData) do
    changed = changed or (self[k] ~= v)
    self[k] = v
  end
  return changed
end

---@class SelectableItem: Item
---@field public selected boolean
local SelectableItem = Item:subclass("SelectableItem")

---@parant scene Scene
function SelectableItem:initialize(scene, id)
  Item.initialize(self, scene, id)
  self.selected = false
end

function SelectableItem:toData()
  local ret = Item.toData(self)
  ret.selected = self.selected
  return ret
end

-- 最基本的“交互”，对应到UI中就是一次点击。
-- 在派生类中视情况可能要为其传入参数表示修改后的值。
function Item:interact() end

--[[
  模拟UI场景。用途是容纳所有模拟UI组件，并与实际的UI进行信息交换。

  在实际针对Scene与Handler进行开发时，Scene只需要创建Item并管理就行了，
  与逻辑相关的代码都在RequestHandler及其子类中编写，然而直接负责管理各个
  UI组件的是Scene。以下是注意事项：

  1. 使用scene:update方法来更新Item的属性：
  -------------------------------

    [QML] cardItem.enabled = true;
    [Lua] scene:update("CardItem", cid, { enabled = true })

  这样做是为了在后续操作中能成功的将此处作出的修改传达给QML。因为没有类似QML的
  属性绑定机制，因此要另外调用update方法来记录相关的属性变动。

  2. 使用Scene提供的方法来访问元素
  ---------------------------------

  例如RoomScene中已经创建了表达卡牌和技能的Item，因此在Handler的逻辑编写中，
  应当避免再去使用getCards或者getSkills这样获取原始属性的函数，而是直接访问Item
  例如：
--]]
---@class Scene: Object
---@field public parent RequestHandler
---@field public scene_name string
---@field public items { [string]: { [string|integer]: Item } }
local Scene = class("Scene")

function Scene:initialize(parent)
  self.parent = parent
  self.items = {}
end

---@param item Item
function Scene:addItem(item, ui_data)
  local key = item.class.name
  self.items[key] = self.items[key] or {}
  self.items[key][item.id] = item
  local changeData = self.parent.change
  if changeData then
    local k = "_new"
    changeData[k] = changeData[k] or {}
    table.insert(changeData[k], {
      type = key,
      data = item:toData(),
      ui_data = ui_data,
    })
  end
end

function Scene:removeItem(elemType, id, ui_data)
  local tab = self.items[elemType]
  if type(tab) ~= "table" then return end
  if not (tab and tab[id]) then return end
  tab[id] = nil
  local changeData = self.parent.change
  if changeData then
    local k = "_delete"
    changeData[k] = changeData[k] or {}
    table.insert(changeData[k], {
      type = elemType,
      id = id,
      ui_data = ui_data,
    })
  end
end

function Scene:getAllItems(elemType)
  return self.items[elemType] or Util.DummyTable
end

-- 模拟一次UI交互，修改相关item的属性即可
-- 同时修改自己parent的changeData
function Scene:update(elemType, id, newData)
  local item = self.items[elemType][id]
  if not item then return end
  local changed = item:setData(newData)
  -- changed = true
  local changeData = self.parent.change
  if changed and changeData then
    changeData[elemType] = changeData[elemType] or {}
    table.insert(changeData[elemType], item:toData())
  end
end

-- 一般由RequestHandler或者其他上层部分调用
-- 调用者需要维护changeData，确保传给UI的数据最少
function Scene:notifyUI()
  if not ClientInstance then return nil end
  self.parent.change["_type"] = self.scene_name
  ClientInstance:notifyUI("UpdateRequestUI", self.parent.change)
end

return {
  Item = Item,
  SelectableItem = SelectableItem,
  Scene = Scene,
}
