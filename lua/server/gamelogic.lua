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
    local n = #self.room.players
    local roles = self.role_table[n]
    table.shuffle(roles)

    for i = 1, n do
        local p = self.room.players[i]
        p.role = roles[i]
        if p.role == "lord" then
            self.room:broadcastProperty(p, "role")
        else
            self.room:notifyProperty(p, p, "role")
        end
    end
end

function GameLogic:chooseGenerals()
    local room = self.room
    local function setPlayerGeneral(player, general)
        local g = Fk.generals[general]
        if g == nil then return end
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
        lord_general = room:askForGeneral(lord, generals);
        setPlayerGeneral(lord, lord_general);
        room:broadcastProperty(lord, "general");
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
        print(p.request_data)
    end

    room:doBroadcastRequest("AskForGeneral", nonlord)
    for _, p in ipairs(nonlord) do
        if p.general == "" and p.reply_ready then
            local general = json.decode(p.client_reply)[1]
            setPlayerGeneral(p, general)
        end
    end
end

function GameLogic:prepareForStart()

end

function GameLogic:action()

end

return GameLogic
