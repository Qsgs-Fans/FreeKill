function table:contains(element)
	if #self == 0 or type(self[1]) ~= type(element) then return false end
	for _, e in ipairs(self) do
		if e == element then return true end
	end
end

function table:insertTable(list)
	for _, e in ipairs(list) do
		table.insert(self, e)
	end
end

local Util = class("Util")

function Util.static:createEnum(tbl, index) 
  assert(IsTable(tbl))
  local enumtbl = {}
  local enumindex = index or 0
  for i, v in ipairs(tbl) do
      enumtbl[v] = enumindex + i
  end
  return enumtbl
end

return Util
