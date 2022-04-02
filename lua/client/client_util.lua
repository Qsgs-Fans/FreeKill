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
