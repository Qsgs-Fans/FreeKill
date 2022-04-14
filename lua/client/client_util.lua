function Translate(src)
    return Fk.translations[src]
end

function GetGeneralData(name)
    local general = Fk.generals[name]
    if general == nil then general = Fk.generals["diaochan"] end
    return json.encode {
        general.kingdom
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
