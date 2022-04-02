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
---@field flag string[]
---@field tag table<string, any>
---@field mark table<string, integer>
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
    self.flag = {}
    self.tag = {}
    self.mark = {}
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
        table.insertTable(self.player_skills, general.skills)
    end
end

---@param flag string
function Player:hasFlag(flag)
    return table.contains(self.flag, flag)
end

---@param flag string
function Player:setFlag(flag)
    if flag == "." then 
        self:clearFlags()
        return
    end
    if flag:sub(1, 1) == "-" then
        flag = flag:sub(2, #flag)
        table.removeOne(self.flag, flag)
        return
    end
    if not self:hasFlag(flag) then
        table.insert(self.flag, flag)
    end
end

function Player:clearFlags()
    self.flag = {}
end

function Player:addMark(mark, count)
    count = count or 1
    local num = self.mark[mark]
    num = num or 0
    self:setMark(mark, math.max(num + count, 0))
end

function Player:removeMark(mark, count)
    count = count or 1
    local num = self.mark[mark]
    num = num or 0
    self:setMark(mark, math.max(num - count, 0))
end

function Player:setMark(mark, count)
    if self.mark[mark] ~= count then
        self.mark[mark] = count
    end
end

function Player:getMark(mark)
    return (self.mark[mark] or 0)
end

function Player:getMarkNames()
    local ret = {}
    for k, _ in pairs(self.mark) do
        table.insert(ret, k)
    end
    return ret
end

return Player
