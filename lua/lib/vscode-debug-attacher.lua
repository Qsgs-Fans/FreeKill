local INSIDERS = false

local os = os
local io = io
local package = package

local function searchDebugger(luaDebugs, tag)
    if INSIDERS then
        tag = tag .. "-insiders"
    end
    local isWindows = package.config:sub(1,1) == "\\"
    local extensionPath = (isWindows and os.getenv "USERPROFILE" or os.getenv "HOME") .. "/.vscode"..tag.."/extensions"
    local command = isWindows and ("dir /B " .. extensionPath:gsub("/", "\\") .. " 2>nul") or ("ls -1 " .. extensionPath .. " 2>/dev/null")
    for name in io.popen(command):lines() do
        local a, b, c = name:match "^actboy168%.lua%-debug%-(%d+)%.(%d+)%.(%d+)"
        if a then
            luaDebugs[#luaDebugs+1] = { a * 10000 + b * 100 + c, extensionPath .. "/" .. name }
        end
    end
end

local function getLatestDebugger()
    local luaDebugs = {}
    searchDebugger(luaDebugs, "")
    searchDebugger(luaDebugs, "-server")
    if #luaDebugs == 0 then
        error "Cant find `actboy168.lua-debug`"
    end
    table.sort(luaDebugs, function (a, b) return a[1] == b[1] and a[2] > b[2] or a[1] > b[1] end)
    return luaDebugs[1][2]
end

local function dofile(filename)
    local load = _VERSION == "Lua 5.1" and loadstring or load
    local f = assert(io.open(filename))
    local str = f:read "*a"
    f:close()

    str = [[
    local os = os
    local io = io
    local package = package
    ]] .. str
    return assert(load(str, "=(debugger.lua)"))(filename)
end

local path = getLatestDebugger()
return dofile(path .. "/script/debugger.lua")
