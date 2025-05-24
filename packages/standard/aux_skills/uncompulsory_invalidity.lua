local uncompulsoryInvalidity = fk.CreateSkill {
  name = "uncompulsory_invalidity",
}

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

uncompulsoryInvalidity:addEffect("invalidity", {
  global = true,
  invalidity_func = function(self, from, skill)
    return
      not skill:hasTag(Skill.Compulsory) and
      skill:isPlayerSkill(from) and
      hasMark(from, MarkEnum.UncompulsoryInvalidity, MarkEnum.TempMarkSuffix)
  end
})

return uncompulsoryInvalidity
