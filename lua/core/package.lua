---@class Package : Object
---@field name string
---@field type number
---@field generals table
---@field extra_skills table
---@field related_skills table
---@field cards table
local Package = class("Package")

-- enum Type
freekill.createEnum(Package, {
    "GeneralPack",
    "CardPack",
    "SpecialPack"
})

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

---@return table skills
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

---@param general General
function Package:addGeneral(general)
    assert(general.class and general:isInstanceOf(General))
    table.insert(self.generals, general)
end

---@param card Card
function Package:addCard(card)
    assert(card.class and card:isInstanceOf(Card))
    card.package = self
    table.insert(self.cards, card)
end

---@param cards Card[]
function Package:addCards(cards)
    for _, card in ipairs(cards) do
        self:addCard(card)
    end
end

return Package
