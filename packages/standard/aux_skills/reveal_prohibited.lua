local revealProhibited = fk.CreateSkill {
  name = "reveal_prohibited",
}

revealProhibited:addEffect("invalidity", {
  global = true,
  invalidity_func = function(self, from, skill)
    local generals = {}
    if type(from:getMark(MarkEnum.RevealProhibited)) == "table" then
      generals = from:getMark(MarkEnum.RevealProhibited)
    end

    for mark, value in pairs(from.mark) do
      if mark:startsWith(MarkEnum.RevealProhibited .. "-") and type(value) == "table" then
        for _, suffix in ipairs(MarkEnum.TempMarkSuffix) do
          if mark:find(suffix, 1, true) then
            for _, g in ipairs(value) do
              table.insertIfNeed(generals, g)
            end
          end
        end
      end
    end
    -- for _, m in ipairs(table.map(MarkEnum.TempMarkSuffix, function(s)
    --     return from:getMark(MarkEnum.RevealProhibited .. s)
    --   end)) do
    --   if type(m) == "table" then
    --     for _, g in ipairs(m) do
    --       table.insertIfNeed(generals, g)
    --     end
    --   end
    -- end

    if #generals == 0 then return false end
    local sname = skill.name
    for _, g in ipairs(generals) do
      if (g == "m" and from.general == "anjiang") or (g == "d" and from.deputyGeneral == "anjiang") then
        local generalName = g == "m" and from:getMark("__heg_general") or from:getMark("__heg_deputy")
        local general = Fk.generals[generalName]
        if table.contains(general:getSkillNameList(true), sname) then
          return true
        end
      end
    end
    return false
  end
})

return revealProhibited
