local uncompulsoryInvalidity = fk.CreateSkill {
  name = "uncompulsory_invalidity",
}

uncompulsoryInvalidity:addEffect("invalidity", {
  global = true,
  invalidity_func = function(self, from, skill)
    ---@param object Card|Player
    ---@param markname string
    ---@param suffixes string[]
    ---@return boolean
    local function hasMark(object, markname, suffixes)
      if not object then return false end
      for mark, _ in pairs(object.mark) do
        if mark == markname then return true end
        if mark:startsWith(markname .. "-") then
          for _, suffix in ipairs(suffixes) do
            if mark:find(suffix, 1, true) then return true end
          end
        end
      end
      return false
    end
    return
      (skill.frequency ~= Skill.Compulsory and skill.frequency ~= Skill.Wake) and
      skill:isPlayerSkill(from) and
      hasMark(from, MarkEnum.UncompulsoryInvalidity, MarkEnum.TempMarkSuffix)
      -- (
      --   from:getMark(MarkEnum.UncompulsoryInvalidity) ~= 0 or
      --   table.find(MarkEnum.TempMarkSuffix, function(s)
      --     return from:getMark(MarkEnum.UncompulsoryInvalidity .. s) ~= 0
      --   end)
      -- )
  end
})

return uncompulsoryInvalidity
