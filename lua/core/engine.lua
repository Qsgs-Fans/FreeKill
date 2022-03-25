local Sanguosha = class("Engine")

function Sanguosha:initialize()
    self.skills = {}
    self.generals = {}
    self.cards = {}
end

function Sanguosha:addSkill(skill)
    table.insert(self.skills, skill)
end

function Sanguosha:addGeneral(general)
    table.insert(self.generals, general)
end

function Sanguosha:addCard(card)
    table.insert(self.cards, cards)
end

function Sanguosha:getGeneralsRandomly(num, generalPool, except, filter)
    if filter then
        assert(type(filter) == "function")
    end

    generalPool = generalPool or self.generals
    except = except or {}
    
    local availableGenerals = {}
    for _, general in ipairs(generalPool) do
        if not table.contains(except, general) and not (filter and filter(general)) then
            table.insert(availableGenerals, general)
        end
    end

    if #availableGenerals == 0 then
        return {}
    end

    local result = {}
    while num > 0 do
        local randomGeneral = math.random(1, #availableGenerals)
        table.insert(result, randomGeneral)
        table.remove(availableGenerals, randomGeneral)

        if #availableGenerals == 0 then
            break
        end
    end

    return result
end

function Sanguosha:getAllGenerals(except)
    local result = {}
    for _, general in ipairs(self.generals) do
        if not (except and table.contains(except, general)) then
            table.insert(result, general)
        end
    end

    return result
end

return Sanguosha
