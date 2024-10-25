local Item = (require 'ui_emu.base').Item

-- 用来表明interaction的Item，格式大约可比照ui-util.lua中的表定义
---@class Interaction: Item
---@field public spec any 弹出的东西
---@field public skill_name string 技能名
---@field public data any skill.interaction.data
local Interaction = Item:subclass("Interaction")

function Interaction:initialize(scene, id, spec)
  Item.initialize(self, scene, id)
  self.spec = spec
  self.enabled = true
end

function Interaction:toData()
  local ret = Item.toData(self)
  ret.spec = self.spec
  ret.skill_name = self.skill_name
  return ret
end

return Interaction
