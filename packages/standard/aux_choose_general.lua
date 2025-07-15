-- SPDX-License-Identifier: GPL-3.0-or-later

--- 无要求选将
Fk:addChooseGeneralRule{
  name = "askForGeneralsChosen",
  card_filter = Util.TrueFunc,
  feasible = function (selected, data, extra_data)
    return #selected == extra_data.n
  end,
  prompt = function(data, extra_data)
    if extra_data.prompt then
      return extra_data.prompt
    else
      local ret = Fk:translate("#AskForChooseGenerals")
      ret = ret:gsub("%%1", Fk:translate(extra_data.skillName or "Fight"))
      ret = ret:gsub("%%2", math.floor(extra_data.n)) -- floor to avoid float number
      return ret
    end
  end,
  default_choice = function(data, extra_data)
    return table.random(data, extra_data.n)
  end
}

---@param general string
---@param other string
---@return boolean
local function isHegPair(general, other)
  if general == other then return false end
  local g1, g2 = Fk.generals[general], Fk.generals[other]
  if string.find(g2.kingdom, "wild") then
    return false
  end
  if string.find(g1.kingdom, "wild") then
    return true
  end
  local k1, k2 = g1.kingdom, g2.kingdom
  local sub1, sub2 = g1.subkingdom, g2.subkingdom

  if k1 == k2 or (sub1 and (sub1 == k2 or sub1 == sub2)) or (sub2 and sub2 == k1) then
    return true
  end
  return false
end

--- 国战选将
Fk:addChooseGeneralRule{
  name = "heg_general_choose",
  card_filter = function (to_select, selected, data, extra_data)
    if #selected == extra_data.n then return false
    elseif #selected == 0 then
      for _, g in ipairs(data) do
        if isHegPair(to_select, g) then
          return true
        end
      end
      return false
    else
      for _, g in ipairs(selected) do
        if not isHegPair(g, to_select) then
          return false
        end
      end
      return true
    end
  end,
  feasible = function (selected, data, extra_data)
    local num = #selected
    if num == extra_data.n then
      if num == 1 then return true end
      for i = 1, num do
        local g = selected[i]
        for j = i + 1, num do
          if not isHegPair(g, selected[j]) then
            return false
          end
        end
      end
      return true
    end
  end,
  prompt = function(data, extra_data)
    if extra_data.prompt then
      return extra_data.prompt
    else
      local ret = Fk:translate("#AskForChooseGenerals")
      ret = ret:gsub("%%1", Fk:translate(extra_data.skillName or "Fight"))
      ret = ret:gsub("%%2", math.floor(extra_data.n)) -- floor to avoid float number
      return ret
    end
  end,
  default_choice = function(data, extra_data)
    local num = extra_data.n
    if num == 1 then return table.random(data, 1) end

    -- 使用回溯法寻找一个长度为num的序列，满足每两个元素都isHegPair
    local n = #data
    local path = {}
    local used = {}

    local function backtrack(depth)
      if depth > num then
        return true
      end
      for i = 1, n do
        if not used[i] then
          local ok = true
          for j = 1, depth - 1 do
            if not isHegPair(path[j], data[i]) then
              ok = false
              break
            end
          end
          if ok then
            path[depth] = data[i]
            used[i] = true
            if backtrack(depth + 1) then
              return true
            end
            used[i] = false
          end
        end
      end
      return false
    end

    if backtrack(1) then
      return {table.unpack(path, 1, num)}
    else
      return {}
    end
  end
}
