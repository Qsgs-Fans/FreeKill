-- 仿效 swig 中 class Room 的接口制作，为了便于测试

local Room = class("fk.Room")

function Room:getId() return 1 end
function Room:getPlayers() return self.players end
function Room:getTimeout() return 15 end
function Room:updateWinRate() end
function Room:gameOver() end
function Room:settings()
  return json.encode{
    enableFreeAssign = false,
    enableDeputy = false,
    gameMode = "testmode",
    disabledPack = {},
    generalNum = 2,
    luckTime = 0,
    password = "",
    disabledGenerals = {},
  }
end

return Room
