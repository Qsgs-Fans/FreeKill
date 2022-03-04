function logic()
    chooseGeneral()
    initSkillList()
    actionNormal()
end

function chooseGeneral()
    for _, p in ipairs(room:getPlayers()) do
        local g = p:askForGeneral()
        room:changeHero(p, g)
    end
end

function actionNormal()
    local p = room:getLord()
    while true do
        room:setCurrent(p)
        act(room:getCurrent)
        p = p:getNextAlive()
    end
end

function trigger() end
