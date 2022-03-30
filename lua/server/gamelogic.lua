---@class GameLogic: Object
local GameLogic = class("GameLogic")

function GameLogic:initialize(room)
    self.room = room
    self.skill_table = {}   -- TriggerEvent --> Skill[]
    self.skills = {}        -- skillName[]
    self.event_stack = Stack:new()

    self.role_table = {
        { "lord" },
        { "lord", "rebel" },
        { "lord", "rebel", "renegade" },
        { "lord", "loyalist", "rebel", "renegade" },
        { "lord", "loyalist", "rebel", "rebel", "renegade" },
        { "lord", "loyalist", "rebel", "rebel", "rebel", "renegade" },
        { "lord", "loyalist", "loyalist", "rebel", "rebel", "rebel", "renegade" },
        { "lord", "loyalist", "loyalist", "rebel", "rebel", "rebel", "rebel", "renegade" },
    }
end

function GameLogic:run()
    -- default logic
    table.shuffle(self.room.players)
    self:assignRoles()
    self.room:adjustSeats()

    self:chooseGenerals()
    self:prepareForStart()
    self:action()
end

function GameLogic:assignRoles()
    local room = self.room
    local n = #room.players
    local roles = self.role_table[n]
    table.shuffle(roles)

    for i = 1, n do
        local p = room.players[i]
        p.role = roles[i]
        if p.role == "lord" then
            room:broadcastProperty(p, "role")
        else
            room:notifyProperty(p, p, "role")
        end
    end
end

function GameLogic:chooseGenerals()
    local room = self.room
    local function setPlayerGeneral(player, general)
        if Fk.generals[general] == nil then return end
        player.general = general
        self.room:notifyProperty(player, player, "general")
    end
    local lord = room:getLord()
    local lord_general = nil
    if lord ~= nil then
        local generals = Fk:getGeneralsRandomly(3)
        for i = 1, #generals do
            generals[i] = generals[i].name
        end
        lord_general = room:askForGeneral(lord, generals)
        setPlayerGeneral(lord, lord_general)
        room:broadcastProperty(lord, "general")
    end

    local nonlord = room:getOtherPlayers(lord)
    local generals = Fk:getGeneralsRandomly(#nonlord * 3, Fk.generals, {lord_general})
    table.shuffle(generals)
    for _, p in ipairs(nonlord) do
        local arg = {
            (table.remove(generals, 1)).name,
            (table.remove(generals, 1)).name,
            (table.remove(generals, 1)).name,
        }
        p.request_data = json.encode(arg)
        p.default_reply = arg[1]
    end

    room:doBroadcastRequest("AskForGeneral", nonlord)
    for _, p in ipairs(nonlord) do
        if p.general == "" and p.reply_ready then
            local general = json.decode(p.client_reply)[1]
            setPlayerGeneral(p, general)
        else
            setPlayerGeneral(p, p.default_reply)
        end
        p.default_reply = ""
    end
end

function GameLogic:prepareForStart()
    local room = self.room
    local players = room.players
    room.alive_players = players
    for i = 1, #players - 1 do
        players[i].next = players[i + 1]
    end
    players[#players].next = players[1]

    for _, p in ipairs(players) do
        assert(p.general ~= "")
        local general = Fk.generals[p.general]
        p.maxHp = general.maxHp
        p.hp = general.hp
        -- TODO: setup AI here

        if p.role ~= "lord" then
            room:broadcastProperty(p, "general")
        elseif #players >= 5 then
            p.maxHp = p.maxHp + 1
            p.hp = p.hp + 1
        end
        room:broadcastProperty(p, "maxHp")
        room:broadcastProperty(p, "hp")

        -- TODO: add skills to player
    end

    -- TODO: prepare drawPile
    -- TODO: init cards in drawPile

    -- TODO: init trigger table for self
end

function GameLogic:action()

end

return GameLogic
