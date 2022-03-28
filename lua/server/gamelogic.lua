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
    self:startGame()
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

end

function GameLogic:startGame()

end

return GameLogic
