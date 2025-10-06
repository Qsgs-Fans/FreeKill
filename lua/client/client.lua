---@type table<string, fun(self: Client, data: any)>
fk.client_callback = {}

dofile "lua/lunarltk/client/client.lua"

-- 总而言之就是会让roomScene.state变为responding或者playing的状态
local pattern_refresh_commands = {
  "PlayCard",
  "AskForUseActiveSkill",
  "AskForUseCard",
  "AskForResponseCard",
}

-- 传了个string且不知道为什么不走cbor.decode的
local no_decode_commands = {
  "ErrorMsg",
  "ErrorDlg",
  "Heartbeat",
  "ServerMessage",

  "UpdateAvatar",
  "UpdatePassword",
}

ClientCallback = function(_self, command, jsonData, isRequest)
  local self = ClientInstance
  if self.recording then
    table.insert(self.record, {math.floor(os.getms() / 1000), isRequest, command, jsonData})
  end

  -- CBOR调试中。。。
  -- print(command, jsonData:gsub(".", function(c) return ("%02x"):format(c:byte()) end))

  local cb = self.callbacks[command] or fk.client_callback[command]
  local data
  if table.contains(no_decode_commands, command) then
    data = jsonData
  else
    data = cbor.decode(jsonData)
  end

  if table.contains(pattern_refresh_commands, command) then
    Fk.currentResponsePattern = nil
    Fk.currentResponseReason = nil
  end

  if (type(cb) == "function") then
    if command:startsWith("AskFor") or command == "PlayCard" then
      self:notifyUI("CancelRequest") -- 确保变成notactive 防止卡双active 权宜之计
    end
    cb(self, data)
  else
    self:notifyUI(command, data)
  end
end

-- Create ClientInstance (used by Lua)
-- Let Cpp call this function to create
function CreateLuaClient(cpp_client)
  ClientInstance = Client:new(cpp_client)
end
dofile "lua/client/client_util.lua"

if FileIO.pwd():endsWith("packages/freekill-core") then
  FileIO.cd("../..")
end
