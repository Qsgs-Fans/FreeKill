local jijiang = fk.CreateSkill {
  name = "jijiang",
  tags = { Skill.Lord },
}

jijiang:addEffect("viewas", {
  anim_type = "offensive",
  pattern = "slash",
  card_filter = Util.FalseFunc,
  view_as = function(self, player, cards)
    if #cards ~= 0 then return end
    local c = Fk:cloneCard("slash")
    c.skillName = jijiang.name
    return c
  end,
  before_use = function(self, player, use)
    local room = player.room
    if use.tos then
      room:doIndicate(player.id, table.map(use.tos, Util.IdMapper))
    end

    for _, p in ipairs(room:getOtherPlayers(player)) do
      if p.kingdom == "shu" then
        local respond = room:askToResponse(p, {
          skill_name = jijiang.name,
          pattern = "slash",
          prompt = "#jijiang-ask:"..player.id,
          cancelable = true,
        })
        if respond then
          respond.skipDrop = true
          room:responseCard(respond)

          use.card = respond.card
          return
        end
      end
    end

    room:setPlayerMark(player, "jijiang_failed-phase", 1)
    return jijiang.name
  end,
  enabled_at_play = function(self, player)
    return player:getMark("jijiang_failed-phase") == 0 and
      table.find(Fk:currentRoom().alive_players, function(p)
        return p.kingdom == "shu" and p ~= player
      end)
  end,
  enabled_at_response = function(self, player)
    return table.find(Fk:currentRoom().alive_players, function(p)
      return p.kingdom == "shu" and p ~= player
    end)
  end,
})

return jijiang
