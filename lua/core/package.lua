local Package = class("Package")

-- enum Type
Package.GeneralPack = 0
Package.CardPack = 1
Package.SpecialPack = 2

-- string name, Type type
function Package:initialize(name, _type)
    assert(type(name) == "string")
    assert(type(_type) == "nil" or type(_type) == "number")
    self.name = name
    self.type = _type or Package.GeneralPack

    self.generals = {}
    -- skill not belongs to any generals, like "jixi"
    self.extra_skills = {}
    -- table: string --> string
    self.related_skills = {}
    self.cards = {}     --> Card[]
end

function Package:getSkills()
    local ret = {table.unpack(self.related_skills)}
    if self.type == Package.GeneralPack then
        for _, g in ipairs(self.generals) do
            for _, s in ipairs(g.skills) do
                table.insert(ret, s)
            end
        end
    end
    return ret
end

function Package:addGeneral(general)
    assert(general.class and general:isInstanceOf(General))
    table.insert(self.generals, general)
end

return Package
