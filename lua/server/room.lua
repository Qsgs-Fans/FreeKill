local Room = class("Room")

function Room:initialize(_room)
    self.room = _room
    self.players = {}       -- ServerPlayer[]
    self.gameFinished = false
end

-- When this function returns, the Room(C++) thread stopped.
function Room:run()
    for _, p in freekill.qlist(self.room:getPlayers()) do
        local player = ServerPlayer:new(p)
        table.insert(self.players, player)
        self.server.players[player:getId()] = player
    end

    self.logic = GameLogic:new(self)
    self.logic:run()
end

function Room:broadcastProperty(player, property)
    for _, p in ipairs(self.players) do
        self:notifyProperty(p, player, property)
    end
end

function Room:notifyProperty(p, player, property)
    p:doNotify("PropertyUpdate", json.encode{
        player:getId(),
        property,
        player[property],
    })
end

function Room:adjustSeats()
    return nil
end

function Room:gameOver()
    self.gameFinished = true
    -- dosomething
    self.room:gameOver()
end

return Room
