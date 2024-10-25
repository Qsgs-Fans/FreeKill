local base = require 'ui_emu.base'
local SelectableItem = base.SelectableItem

---@class CardItem: SelectableItem
local CardItem = SelectableItem:subclass("CardItem")

---@class Photo: SelectableItem
---@field public state string
local Photo = SelectableItem:subclass("Photo")

function Photo:initialize(scene, id)
  SelectableItem.initialize(self, scene, id)
  self.state = "normal"
end

function Photo:toData()
  local ret = SelectableItem.toData(self)
  ret.state = self.state
  return ret
end

---@class SkillButton: SelectableItem
local SkillButton = SelectableItem:subclass("SkillButton")

return {
  CardItem = CardItem,
  Photo = Photo,
  SkillButton = SkillButton,
}
