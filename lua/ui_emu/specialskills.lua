local Item = (require 'ui_emu.base').Item

-- 用来表明SpecialSkills的Item，本质是一个单选框
---@class SpecialSkills: Item
---@field public skills string[] 技能名
---@field public data any orig_text
local SpecialSkills = Item:subclass("SpecialSkills")

function SpecialSkills:initialize(scene, id)
  Item.initialize(self, scene, id)
  self.skills = {}
  self.enabled = true
end

function SpecialSkills:toData()
  local ret = Item.toData(self)
  ret.skills = self.skills
  return ret
end

return SpecialSkills
