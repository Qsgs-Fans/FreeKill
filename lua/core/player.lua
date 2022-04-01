---@class Player : Object
---@field hp integer
---@field maxHp integer
---@field kingdom string
---@field role string
---@field general string
---@field handcard_num integer
---@field seat integer
---@field phase integer
---@field faceup boolean
---@field chained boolean
---@field dying boolean
---@field dead boolean
---@field state string
---@field playerSkills Skill[]
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

---@param general General
---@param setHp boolean
---@param addSkills boolean
function Player:setGeneral(general, setHp, addSkills)
    self.general = general
    if setHp then
        self.maxHp = general.maxHp
        self.hp = general.hp
    end

    if addSkills then
        table.insertTable(self.playerSkills, general.skills)
    end
end

return Player
