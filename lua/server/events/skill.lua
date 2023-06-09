-- SPDX-License-Identifier: GPL-3.0-or-later

GameEvent.functions[GameEvent.SkillEffect] = function(self)
  local effect_cb, player, skill = table.unpack(self.data)
  local room = self.room
  local logic = room.logic

  local cost_data_bak = skill.cost_data
  logic:trigger(fk.SkillEffect, player, skill)
  skill.cost_data = cost_data_bak

  local ret = effect_cb()

  logic:trigger(fk.AfterSkillEffect, player, skill)
  return ret
end
