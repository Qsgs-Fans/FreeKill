local sk = fk.CreateSkill{
  name = "armor_invalidity",
}

sk:addEffect('invalidity', {
  global = true,
  invalidity_func = function(self, player, skill)
    if skill:getSkeleton().attached_equip and
      Fk:cloneCard(skill:getSkeleton().attached_equip).sub_type == Card.SubtypeArmor then
      if player:getMark(MarkEnum.MarkArmorNullified) > 0 then return true end

      --无视防具（规则集版）！
      if not RoomInstance then return end
      local logic = RoomInstance.logic
      local event = logic:getCurrentEvent()
      local from = nil
      repeat
        local data = event.data
        if event.event == GameEvent.SkillEffect then
          ---@cast data SkillEffectData
          if not data.skill.cardSkill then
            from = data.who
            break
          end
        elseif event.event == GameEvent.Damage then
          ---@cast data DamageData
          if data.to ~= player then return false end
          from = data.from
          break
        elseif event.event == GameEvent.UseCard then
          ---@cast data UseCardData
          if not table.contains(data.tos, player) then return false end
          from = data.from
          break
        end
        event = event.parent
      until event == nil
      if from then
        local suffixes = {""}
        table.insertTable(suffixes, MarkEnum.TempMarkSuffix)
        for _, suffix in ipairs(suffixes) do
          if table.contains(from:getTableMark(MarkEnum.MarkArmorInvalidTo .. suffix), player.id) or
            table.contains(player:getTableMark(MarkEnum.MarkArmorInvalidFrom .. suffix), from.id) then
            return true
          end
        end
      end
    end
  end
})

return sk
