---@class Player : Object
---@field hp integer
---@field maxHp integer
---@field kingdom string
---@field role string
---@field general string
---@field handcard_num integer
---@field seat integer
---@field phase Phase
---@field faceup boolean
---@field chained boolean
---@field dying boolean
---@field dead boolean
---@field state string
---@field player_skills Skill[]
local Player = class("Player")

---@alias Phase integer

Player.RoundStart = 1
Player.Start = 2
Player.Judge = 3
Player.Draw = 4
Player.Play = 5
Player.Discard = 6
Player.Finish = 7
Player.NotActive = 8
Player.PhaseNone = 9

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

    self.player_skills = {}
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
