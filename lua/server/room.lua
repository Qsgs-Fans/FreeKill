---@class Room : Object
local Room = class("Room")

function Room:initialize(_room)
    self.room = _room
    self.players = {}       -- ServerPlayer[]
    self.alive_players = {}
    self.game_finished = false
    self.timeout = _room:getTimeout()
end

-- When this function returns, the Room(C++) thread stopped.
function Room:run()
    for _, p in freekill.qlist(self.room:getPlayers()) do
        local player = ServerPlayer:new(p)
        player.state = p:getStateString()
        player.room = self
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

function Room:doBroadcastNotify(command, jsonData, players)
    players = players or self.players
    local tolist = freekill.SPlayerList()
    for _, p in ipairs(players) do
        tolist:append(p.serverplayer)
    end
    self.room:doBroadcastNotify(tolist, command, jsonData)
end

function Room:doRequest(player, command, jsonData, wait)
    if wait == nil then wait = true end
    player:doRequest(command, jsonData, self.timeout)

    if wait then
        return player:waitForReply(self.timeout)
    end
end

function Room:doBroadcastRequest(command, players)
    players = players or self.players
    self:notifyMoveFocus(players, command)
    for _, p in ipairs(players) do
        self:doRequest(p, command, p.request_data, false)
    end

    local remainTime = self.timeout
    local currentTime = os.time()
    local elapsed = 0
    for _, p in ipairs(players) do
        elapsed = os.time() - currentTime
        remainTime = remainTime - elapsed
        p:waitForReply(remainTime)
    end
end

function Room:notifyMoveFocus(players, command)
    if (players.class) then
        players = {players}
    end

    local ids = {}
    for _, p in ipairs(players) do
        table.insert(ids, p:getId())
    end

    self:doBroadcastNotify("MoveFocus", json.encode{
        ids,
        command
    })
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

function Room:getLord()
    local lord = self.players[1]
    if lord.role == "lord" then return lord end
    for _, p in ipairs(self.players) do
        if p.role == "lord" then return p end
    end

    return nil
end

function Room:getOtherPlayers(expect)
    local ret = {table.unpack(self.players)}
    table.removeOne(ret, expect)
    return ret
end

function Room:askForGeneral(player, generals)
    local command = "AskForGeneral"
    self:notifyMoveFocus(player, command)

    if #generals == 1 then return generals[1] end
    local defaultChoice = generals[1]

    if (player.state == "online") then
        local result = self:doRequest(player, command, json.encode(generals))
        if result == "" then
            return defaultChoice
        else
            -- TODO: result is a JSON array
            -- update here when choose multiple generals
            return json.decode(result)[1]
        end
    end

    return defaultChoice
end

function Room:gameOver()
    self.game_finished = true
    -- dosomething
    self.room:gameOver()
end

return Room
