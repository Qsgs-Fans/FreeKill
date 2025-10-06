local damage_maker = fk.CreateSkill{
  name = "damage_maker",
}

Fk:loadTranslationTable{
  ["damage_maker"] = "制伤",
  [":damage_maker"] = "出牌阶段，你可以进行一次伤害制造器。",
  ["#damage_maker"] = "制伤：选择一名小白鼠，可选另一名角色做伤害来源（默认谋徐盛）",
  ["#revive-ask"] = "复活一名角色！",
  ["damage_maker_tip_1"] = "目标",
  ["damage_maker_tip_2"] = "来源",
  ["#damage_maker_choose_number"] = "%arg：选择数值",

  ["$damage_maker"] = "区区数百魏军，看我一击灭之！",

  ["heal_hp"] = "回复体力",
  ["lose_max_hp"] = "减体力上限",
  ["heal_max_hp"] = "加体力上限",
  ["shield"] = "护甲",
  ["rest"] = "休整",
  ["kill"] = "杀死",
  ["revive"] = "复活",
}

damage_maker:addEffect("active", {
  anim_type = "offensive",
  mute = true,
  prompt = "#damage_maker",
  can_use = Util.TrueFunc,
  card_filter = Util.FalseFunc,
  card_num = 0,
  target_filter = function(self, player, to_select, selected)
    if self.interaction.data == "revive" then return false end
    return #selected < 2
  end,
  min_target_num = function(self)
    return self.interaction.data == "revive" and 0 or 1
  end,
  max_target_num = function(self)
    return self.interaction.data == "revive" and 0 or 2
  end,
  interaction = function(self, player)
    local damageNatures = player:getMark("damageNatures") ---@type string[]
    if damageNatures == 0 then
      damageNatures = {}
      for k, v in pairs(Fk:getDamageNatures()) do
        table.insert(damageNatures, v[1])
      end
      player:setMark("damageNatures", damageNatures)
    end
    local choices = table.connect(damageNatures, {"lose_hp", "heal_hp", "lose_max_hp", "heal_max_hp", "shield", "rest", "kill", "revive"})
    return UI.ComboBox {
      choices = choices
    }
  end,
  on_use = function(self, room, effect)
    local victim = effect.tos[1]
    local target = #effect.tos > 1 and effect.tos[2] or nil
    local from = target or effect.from -- 来源
    local choice = self.interaction.data ---@type string
    effect.from:broadcastSkillInvoke("damage_maker")
    room:notifySkillInvoked(effect.from, "damage_maker",
      table.contains({"heal_hp", "heal_max_hp", "revive"}, choice)
    and "support" or "offensive", effect.tos)
    local number
    if choice ~= "revive" and choice ~= "kill" then
      local choices = {}
      for i = 1, 99 do
        table.insert(choices, tostring(i))
      end
      number = tonumber(room:askToChoice(effect.from, { ---@type integer
        choices = choices,
        skill_name = damage_maker.name,
        prompt = "#damage_maker_choose_number:::" .. choice
      }))
    end
    if choice == "heal_hp" then
      room:recover{
        who = victim,
        num = number,
        recoverBy = from,
        skillName = damage_maker.name
      }
    elseif choice == "heal_max_hp" then
      room:changeMaxHp(victim, number)
    elseif choice == "lose_max_hp" then
      room:changeMaxHp(victim, -number)
    elseif choice == "lose_hp" then
      room:loseHp(victim, number, damage_maker.name)
    elseif choice == "shield" then
      room:changeShield(victim, number)
    elseif choice == "rest" then
      room:killPlayer{
        who = victim,
      }
      victim._splayer:setDied(false)
      room:setPlayerRest(victim, number)
    elseif choice == "kill" then
      room:killPlayer{
        who = victim,
        killer = from,
      }
    elseif choice == "revive" then
      local tos = table.map(table.filter(room.players, function(p) return p.dead end), function(p) return "seat#" .. tostring(p.seat) end)
      if #tos > 0 then
        local targets = room:askToChoice(from, {choices = tos, skill_name = damage_maker.name, prompt = "#revive-ask"})
        if targets then
          local to = tonumber(string.sub(targets, 6))
          for _, p in ipairs(room.players) do
            if p.seat == to then
              room:revivePlayer(p, true)
              break
            end
          end
        end
      end
    else
      local choices = from:getMark("natureToKey")
      if choices == 0 then
        choices = {}
        for k, v in pairs(Fk:getDamageNatures()) do
          choices[v[1]] = k
        end
        from:setMark("natureToKey", choices)
      end
      room:damage({
        from = from,
        to = victim,
        damage = number,
        damageType = choices[choice],
        skillName = damage_maker.name
      })
    end
  end,
  target_tip = function(self, _, to_select, selected, _, _, selectable, _)
    if not selectable then return end
    if #selected == 0 or (#selected > 0 and selected[1] == to_select) then
      return "damage_maker_tip_1"
    else
      return "damage_maker_tip_2"
    end
  end,
})

return damage_maker
