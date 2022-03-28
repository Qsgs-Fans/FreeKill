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

function Room:doBroadcastNotify(command, jsonData)
    self.room:doBroadcastNotify(self.room:getPlayers(), command, jsonData)
end

function Room:adjustSeats()
    local players = {}
    local p = 0

    for i = 1, #self.players do
        if self.players[i].role == "lord" then
            p = i
            break
        end
    end
    for j = p, #self.players do
        table.insert(players, self.players[j])
    end
    for j = 1, p - 1 do
        table.insert(players, self.players[j])
    end

    self.players = players

    local player_circle = {}
    for i = 1, #self.players do
        self.players[i].seat = i
        table.insert(player_circle, self.players[i]:getId())
    end

    self:doBroadcastNotify("ArrangeSeats", json.encode(player_circle))
end

function Room:gameOver()
    self.gameFinished = true
    -- dosomething
    self.room:gameOver()
end

return Room
