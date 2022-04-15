function Translate(src)
    return Fk.translations[src]
end

function GetGeneralData(name)
    local general = Fk.generals[name]
    if general == nil then general = Fk.generals["diaochan"] end
    return json.encode {
        kingdom = general.kingdom,
        hp = general.hp,
        maxHp = general.maxHp
    }
end

function GetCardData(id)
    local card = Fk.cards[id]
    if card == nil then return json.encode{
        cid = id,
        known = false
    } end
    return json.encode{
        cid = id,
        name = card.name,
        number = card.number,
        suit = card:getSuitString(),
        color = card.color,
    }
end

function GetAllGeneralPack()
    local ret = {}
    for _, name in ipairs(Fk.package_names) do
        if Fk.packages[name].type == Package.GeneralPack then
            table.insert(ret, name)
        end
    end
    return json.encode(ret)
end

function GetGenerals(pack_name)
    local ret = {}
    for _, g in ipairs(Fk.packages[pack_name].generals) do
        table.insert(ret, g.name)
    end
    return json.encode(ret)
end

function GetAllCardPack()
    local ret = {}
    for _, name in ipairs(Fk.package_names) do
        if Fk.packages[name].type == Package.CardPack then
            table.insert(ret, name)
        end
    end
    return json.encode(ret)
end

function GetCards(pack_name)
    local ret = {}
    for _, c in ipairs(Fk.packages[pack_name].cards) do
        table.insert(ret, c.id)
    end
    return json.encode(ret)
end
