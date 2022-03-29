local Player = class("Player")

function Player:initialize()
    self.hp = 0
    self.maxHp = 0
    self.kingdom = "qun"
    self.role = ""
    self.general = ""
    self.handcard_num = 0
    self.seat = 0
    self.phase = Player.PhaseNone
    self.faceup = true
    self.chained = false
    self.dying = false
    self.dead = false
    self.state = ""
    
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
