-- SPDX-License-Identifier: GPL-3.0-or-later

---@class StatusSkill : Skill
---@field public global boolean
local StatusSkill = Skill:subclass("StatusSkill")

function StatusSkill:initialize(name, frequency)
  frequency = frequency or Skill.Compulsory
  Skill.initialize(self, name, frequency)
  self.global = false
end

return StatusSkill
