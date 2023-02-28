GameEvent.functions[GameEvent.SkillEffect] = function(self)
  local effect_cb = table.unpack(self.data)
  return effect_cb()
end
