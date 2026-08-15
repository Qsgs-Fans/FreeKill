local base = require 'ui_emu.base'
local SelectableItem = base.SelectableItem

---@class CardItem: SelectableItem
---@field public card? Card 牌的通用信息（只有虚拟牌才有的原始信息）
local CardItem = SelectableItem:subclass("CardItem")

function CardItem:initialize(scene, id)
  local card
  if type(id) == "table" then
    ---@cast id Card
    card = id
    id = Fk:currentRoom():getVirtCardId(id)
  end
  SelectableItem.initialize(self, scene, id)
  if card then
    self.card = card
  else
    Fk:filterCard(id, Fk:currentRoom():getCardOwner(id))
  end
end

function CardItem:toData()
  local ret = SelectableItem.toData(self)
  ret.card = self.card
  return ret
end

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
