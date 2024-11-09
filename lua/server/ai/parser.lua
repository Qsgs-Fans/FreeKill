--- 用于从on_use/on_effect等函数自动生成AI推理用的模拟流程

---@class AIParser
local AIParser = {}

---@type table<string, string[]> 文件名-lines
local loaded_files = {}

local function getLines(filename)
  if loaded_files[filename] then return loaded_files[filename] end
  if UsingNewCore then
    if filename:startsWith("./lua") then
      filename = "./packages/freekill-core/" .. filename
    end
    FileIO.cd("../..")
  end

  local t = {}
  for line in io.lines(filename) do
    table.insert(t, line)
  end
  loaded_files[filename] = t

  if UsingNewCore then
    FileIO.cd("packages/freekill-core")
  end
  return t
end

local function getFunctionSource(fn)
  local info = debug.getinfo(fn, "S")
  local lines = getLines(info.short_src)
  return table.slice(lines, info.linedefined, info.lastlinedefined + 1)
end

-- 最简单替换：breakEvent改成return
function AIParser.parseEventFunc(fn)
  local sources = getFunctionSource(fn)
  local parsed = {}
  for i, line in ipairs(sources) do
    if i == 1 then
      table.insert(parsed, "return function(self)")
    else
      if line:find(":breakEvent%(") then
        line = "return true"
      end
      table.insert(parsed, line)
    end
  end
  return load(table.concat(parsed, '\n'))()
end

function AIParser.parseEventWrapper(wrapperFn)
  local sources = getFunctionSource(wrapperFn)
  print(table.concat(sources, "\n"))
end

return AIParser
