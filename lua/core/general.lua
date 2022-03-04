General = class("General")

function General:initialize(package, name, kingdom, hp, maxHp, gender)
    self.package = package
    self.name = name
    self.kingdom = kingdom
    self.hp = hp
    self.maxHp = maxHp
    self.gender = gender

    self.skills = {}
end

function General:addSkill(skill)
    print "skill add"
end

return General
