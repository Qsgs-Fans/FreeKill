General = class("General")

function General:initialize(package, name, kingdom, hp, maxHp, gender, initialHp)
    self.package = package
    self.name = name
    self.kingdom = kingdom
    self.hp = hp
    self.maxHp = maxHp
    self.gender = gender
    self.initialHp = initialHp or maxHp

    self.skills = {}
end

function General:addSkill(skill)
    table.insert(self.skills, skill)
end

return General
