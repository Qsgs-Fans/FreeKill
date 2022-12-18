-- FreeKill's fkparse interface
-- fkparse (FreeKill parser), a game code generator
-- For license information, check generated lua files.

-- In most cases, fk's basic modules are loaded before extension calls
-- "require 'fkparser'", so we needn't to import lua modules here.

fkp = {
  functions = {},
  newlist = function(t)
    t.length = function(self)
      return #self
    end,

    t.prepend = function(self, element)
      if #self > 0 and type(self[1]) ~= type(element) then return end
      for i = #self, 1, -1 do
        self[i + 1] = self[i]
      end
      self[1] = element
    end,

    t.append = function(self, element)
      if #self > 0 and type(self[1]) ~= type(element) then return end
      table.insert(self, element)
    end,

    t.removeOne = function(self, element)
      if #self == 0 or type(self[1]) ~= type(element) then return false end

      for i = 1, #self do
        if self[i] == element then
          table.remove(self, i)
          return true
        end
      end
      return false
    end,

    t.at = function(self, index)
      return self[index + 1]
    end,

    t.replace = function(self, index, value)
      self[index + 1] = value
    end,
    return t
  end,
}

fkp.functions.prepend = function(arr, e)
  if arr:length() == 0 then
    arr = fkp.newlist{e}
  else
    arr:prepend(e)
  end
  return arr
end,

fkp.functions.append = function(arr, e)
  if arr:length() == 0 then
    arr = fkp.newlist{e}
  else
    arr:append(e)
  end
  return arr
end,

