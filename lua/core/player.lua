local Player = class("Player")

function Player:initialize()
    self.hp = nil
    self.maxHp = nil
    self.general = nil
    self.dying = false
    self.dead = false
    self.playerSkills = {}
end

function Player:setGeneral(general, setHp, addSkills)
    self.general = general
    if setHp then
        self.maxHp = general.maxHp
        self.hp = general.initialHp
    end

    if addSkills then
        table.insertTable(self.playerSkills, general.skills)
    end
end

function Player:setHp(maxHp, initialHp)
    self.maxHp = maxHp
    self.hp = initialHp or maxHp
end

return Player
