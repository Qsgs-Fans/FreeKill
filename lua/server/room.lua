---@class Room : Object
---@field room fk.Room
---@field players ServerPlayer[]
---@field alive_players ServerPlayer[]
---@field current ServerPlayer
---@field game_finished boolean
---@field timeout integer
---@field tag table<string, any>
---@field draw_pile integer[]
---@field card_place table<integer, CardArea>
local Room = class("Room")

-- load classes used by the game
GameLogic = require "server.gamelogic"
ServerPlayer = require "server.serverplayer"

fk.room_callback = {}

---@param _room fk.Room
function Room:initialize(_room)
    self.room = _room
    self.room.callback = function(_self, command, jsonData)
        local cb = fk.room_callback[command]
        if (type(cb) == "function") then
            cb(jsonData)
        else
            print("Lobby error: Unknown command " .. command);
        end
    end

    self.room.startGame = function(_self)
        self:run()
    end

    self.players = {}
    self.alive_players = {}
    self.current = nil
    self.game_finished = false
    self.timeout = _room:getTimeout()
    self.tag = {}
    self.draw_pile = {}
    self.discard_pile = {}
    self.processing_area = {}
    self.void = {}
    self.card_place = {}
end

-- When this function returns, the Room(C++) thread stopped.
function Room:run()
    for _, p in fk.qlist(self.room:getPlayers()) do
        local player = ServerPlayer:new(p)
        player.state = p:getStateString()
        player.room = self
        table.insert(self.players, player)
    end

    self.logic = GameLogic:new(self)
    self.logic:run()
end

---@param player ServerPlayer
---@param property string
function Room:broadcastProperty(player, property)
    for _, p in ipairs(self.players) do
        self:notifyProperty(p, player, property)
    end
end

---@param p ServerPlayer
---@param player ServerPlayer
---@param property string
function Room:notifyProperty(p, player, property)
    p:doNotify("PropertyUpdate", json.encode{
        player:getId(),
        property,
        player[property],
    })
end

---@param command string
---@param jsonData string
---@param players ServerPlayer[] @ default all players
function Room:doBroadcastNotify(command, jsonData, players)
    players = players or self.players
    local tolist = fk.SPlayerList()
    for _, p in ipairs(players) do
        tolist:append(p.serverplayer)
    end
    self.room:doBroadcastNotify(tolist, command, jsonData)
end

---@param player ServerPlayer
---@param command string
---@param jsonData string
---@param wait boolean @ default true
---@return string | nil
function Room:doRequest(player, command, jsonData, wait)
    if wait == nil then wait = true end
    player:doRequest(command, jsonData, self.timeout)

    if wait then
        return player:waitForReply(self.timeout)
    end
end

---@param command string
---@param players ServerPlayer[]
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

---@param players ServerPlayer | ServerPlayer[]
---@param command string
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

function Room:shuffleDrawPile()
    if #self.draw_pile + #self.discard_pile == 0 then
        return
    end

    table.insertTable(self.draw_pile, self.discard_pile)
    self.discard_pile = {}
    table.shuffle(self.draw_pile)
end

---@param num integer
---@param from string
---@return integer[]
function Room:getNCards(num, from)
    from = from or "top"
    assert(from == "top" or from == "bottom")

    local cardIds = {}
    while num > 0 do
        if #self.draw_pile < 1 then
            self:shuffleDrawPile()
        end

        local index = from == "top" and 1 or #self.draw_pile
        table.insert(cardIds, self.draw_pile[index])
        table.remove(self.draw_pile, index)

        num = num - 1
    end

    return cardIds
end

---@param cardId integer
---@param cardArea CardArea
function Room:setCardArea(cardId, cardArea)
    self.card_place[cardId] = cardArea
end

---@param cardId integer
---@return CardArea
function Room:getCardArea(cardId)
    return self.card_place[cardId] or Card.Unknown
end

---@alias CardsMoveInfo {ids: integer[], from: integer|null, to: integer|null, toArea: CardArea, moveReason: CardMoveReason, proposer: integer, skillName: string|null, moveVisible: boolean|null, specialName: string|null, specialVisible: boolean|null }
---@alias MoveInfo {cardId: integer, fromArea: CardArea}
---@alias CardsMoveStruct {moveInfo: {id: integer, fromArea: CardArea}[], from: integer|null, to: integer|null, toArea: CardArea, moveReason: CardMoveReason, proposer: integer|null, skillName: string|null, moveVisible: boolean|null, specialName: string|null, specialVisible: boolean|null, fromSpecialName: string|null }

---@vararg CardsMoveInfo
---@return boolean
function Room:moveCards(...)
    ---@type CardsMoveStruct[]
    local cardsMoveStructs = {}
    local infoCheck = function(info)
        assert(table.contains({ Card.PlayerHand, Card.PlayerEquip, Card.PlayerJudge, Card.PlayerSpecial, Card.Processing, Card.DrawPile, Card.DiscardPile, Card.Void }, info.toArea))
        assert(info.toArea ~= Card.PlayerSpecial or type(info.specialName) == "string")
        assert(type(info.moveReason) == "number")
    end

    for _, cardsMoveInfo in ipairs({...}) do
        if #cardsMoveInfo.ids > 0 then
            infoCheck(cardsMoveInfo)

            ---@type MoveInfo[]
            local infos = {}
            for _, id in ipairs(cardsMoveInfo.ids) do
                table.insert(infos, { cardId = id, fromArea = self:getCardArea(id) })
            end
    
            ---@type CardsMoveStruct
            local cardsMoveStruct = {
                moveInfo = infos,
                from = cardsMoveInfo.from,
                to = cardsMoveInfo.to,
                toArea = cardsMoveInfo.toArea,
                moveReason = cardsMoveInfo.moveReason,
                proposer = cardsMoveInfo.proposer,
                skillName = cardsMoveInfo.skillName,
                moveVisible = cardsMoveInfo.moveVisible,
                specialName = cardsMoveInfo.specialName,
                specialVisible = cardsMoveInfo.specialVisible,
            }
    
            table.insert(cardsMoveStructs, cardsMoveStruct)
        end
    end

    if #cardsMoveStructs < 1 then
        return false
    end

    if self.logic:trigger(fk.BeforeCardsMove, nil, cardsMoveStructs) then
        return false
    end

    for _, data in ipairs(cardsMoveStructs) do
        if #data.moveInfo > 0 then
            infoCheck(data)

            ---@param info MoveInfo
            for _, info in ipairs(data.moveInfo) do
                local realFromArea = self:getCardArea(info.cardId)
                local playerAreas = { Player.Hand, Player.Equip, Player.Judge, Player.Special }

                if table.contains(playerAreas, realFromArea) and data.from then
                    self:getPlayerById(data.from):removeCards(realFromArea, { info.cardId }, data.specialName)
                elseif realFromArea ~= Card.Unknown then
                    local fromAreaIds = {}
                    if realFromArea == Card.Processing then
                        fromAreaIds = self.processing_area
                    elseif realFromArea == Card.DrawPile then
                        fromAreaIds = self.draw_pile
                    elseif realFromArea == Card.DiscardPile then
                        fromAreaIds = self.discard_pile
                    elseif realFromArea == Card.Void then
                        fromAreaIds = self.void
                    end

                    table.removeOne(fromAreaIds, info.cardId)
                end

                if table.contains(playerAreas, data.toArea) and data.to then
                    self:getPlayerById(data.to):addCards(data.toArea, { info.cardId }, data.specialName)
                    self:setCardArea(info.cardId, data.toArea)
                else
                    local toAreaIds = {}
                    if data.toArea == Card.Processing then
                        toAreaIds = self.processing_area
                    elseif data.toArea == Card.DrawPile then
                        toAreaIds = self.draw_pile
                    elseif data.toArea == Card.DiscardPile then
                        toAreaIds = self.discard_pile
                    elseif data.toArea == Card.Void then
                        toAreaIds = self.void
                    end

                    table.insert(toAreaIds, toAreaIds == Card.DrawPile and 1 or #toAreaIds + 1, info.cardId)
                    self:setCardArea(info.cardId, data.toArea)
                end
            end
        end
    end

    self.logic:trigger(fk.AfterCardsMove, nil, cardsMoveStructs)
    return true
end

---@param player ServerPlayer
---@param num integer
---@param skillName string
---@param fromPlace "top"|"bottom"
---@return integer[]
function Room:drawCards(player, num, skillName, fromPlace)
    local topCards = self:getNCards(num, fromPlace)
    self:moveCards({
        ids = topCards,
        to = player:getId(),
        toArea = Card.PlayerHand,
        moveReason = fk.ReasonDraw,
        proposer = player:getId(),
        skillName = skillName,
    })

    return { table.unpack(topCards) }
end

---@param id integer
---@return ServerPlayer
function Room:getPlayerById(id)
    assert(type(id) == "number")

    for _, p in ipairs(self.players) do
        if p:getId() == id then
            return p
        end
    end

    error("cannot find player by " .. id)
end

---@return ServerPlayer | null
function Room:getLord()
    local lord = self.players[1]
    if lord.role == "lord" then return lord end
    for _, p in ipairs(self.players) do
        if p.role == "lord" then return p end
    end

    return nil
end

---@param expect ServerPlayer
---@return ServerPlayer[]
function Room:getOtherPlayers(expect)
    local ret = {table.unpack(self.players)}
    table.removeOne(ret, expect)
    return ret
end

---@param player ServerPlayer
---@param generals string[]
---@return string
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

---@param id integer
function Room:findPlayerById(id)
    for _, p in ipairs(self.players) do
        if p:getId() == id then
            return p
        end
    end
    return nil
end

---@param player ServerPlayer
---@param choices string[]
---@param skill_name string
function Room:askForChoice(player, choices, skill_name, data)
    if #choices == 1 then return choices[1] end
    local command = "AskForChoice"
    self:notifyMoveFocus(player, skill_name)
    local result = self:doRequest(player, command, json.encode{
        choices, skill_name
    })
    if result == "" then result = choices[1] end
    return result
end

---@param player ServerPlayer
---@param skill_name string
---@return boolean
function Room:askForSkillInvoke(player, skill_name, data)
    local command = "AskForSkillInvoke"
    self:notifyMoveFocus(player, skill_name)
    local invoked = false
    local result = self:doRequest(player, command, skill_name)
    if result ~= "" then invoked = true end
    return invoked
end

fk.room_callback["QuitRoom"] = function(jsonData)
    -- jsonData: [ int uid ]
    local data = json.decode(jsonData)
    local player = fk.ServerInstance:findPlayer(tonumber(data[1]))
    local room = player:getRoom()
    if not room:isLobby() then
        room:removePlayer(player)
    end
end

fk.room_callback["AddRobot"] = function(jsonData)
    -- jsonData: [ int uid ]
    local data = json.decode(jsonData)
    local player = fk.ServerInstance:findPlayer(tonumber(data[1]))
    local room = player:getRoom()
    
    if not room:isLobby() then
        room:addRobot(player)
    end
end

fk.room_callback["PlayerRunned"] = function(jsonData)
    -- jsonData: [ int runner_id, int robot_id ]
    -- note: this function is not called by Router.
    -- note: when this function is called, the room must be started
    local data = json.decode(jsonData)
    local runner = data[1]
    local robot = data[2]
    for _, p in ipairs(RoomInstance.players) do
        if p:getId() == runner then
            p.serverplayer = RoomInstance.room:findPlayer(robot)
            p.id = p.serverplayer:getId()
        end
    end
end

fk.room_callback["PlayerStateChanged"] = function(jsonData)
    -- jsonData: [ int uid, string stateString ]
    -- note: this function is not called by Router.
    -- note: when this function is called, the room must be started
    local data = json.decode(jsonData)
    local id = data[1]
    local stateString = data[2]
    RoomInstance:findPlayerById(id).state = stateString
end

fk.room_callback["RoomDeleted"] = function(jsonData)
    debug.sethook(function ()
        error("Room is deleted when running")
    end, "l")
end

fk.room_callback["DoLuaScript"] = function(jsonData)
    -- jsonData: [ int uid, string luaScript ]
    -- warning: only use this in debugging mode.
    if not DebugMode then return end
    local data = json.decode(jsonData)
    assert(load(data[2]))()
end

function CreateRoom(_room)
    RoomInstance = Room:new(_room)
end
