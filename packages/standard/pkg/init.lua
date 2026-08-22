local extension = Package:new("standard")

local prefix = "packages."
if UsingNewCore then prefix = "packages.freekill-core." end

local path = "./packages/standard/pkg/skills"
if UsingNewCore then
  path = "./packages/freekill-core/standard/pkg/skills"
end
extension:loadSkillSkelsByPath(path)

General:new(extension, "caocao", "wei", 4):addSkills { "jianxiong", "hujia" }
General:new(extension, "simayi", "wei", 3):addSkills { "guicai", "fankui" }
General:new(extension, "xiahoudun", "wei", 4):addSkills { "ganglie" }
General:new(extension, "zhangliao", "wei", 4):addSkills { "tuxi" }
General:new(extension, "xuchu", "wei", 4):addSkills { "luoyi" }
General:new(extension, "guojia", "wei", 3):addSkills { "tiandu", "yiji" }
General:new(extension, "zhenji", "wei", 3, 3, General.Female):addSkills { "luoshen", "qingguo" }

General:new(extension, "liubei", "shu", 4):addSkills { "rende", "jijiang" }
General:new(extension, "guanyu", "shu", 4):addSkills { "wusheng" }
General:new(extension, "zhangfei", "shu", 4):addSkills { "paoxiao" }
General:new(extension, "zhugeliang", "shu", 3):addSkills { "guanxing", "kongcheng" }
General:new(extension, "zhaoyun", "shu", 4):addSkills { "longdan" }
General:new(extension, "machao", "shu", 4):addSkills { "mashu", "tieqi" }
General:new(extension, "huangyueying", "shu", 3, 3, General.Female):addSkills { "jizhi", "qicai" }

General:new(extension, "sunquan", "wu", 4):addSkills { "zhiheng", "jiuyuan" }
General:new(extension, "ganning", "wu", 4):addSkills { "qixi" }
General:new(extension, "lvmeng", "wu", 4):addSkills { "keji" }
General:new(extension, "huanggai", "wu", 4):addSkills { "kurou" }
General:new(extension, "zhouyu", "wu", 3):addSkills { "yingzi", "fanjian" }
General:new(extension, "daqiao", "wu", 3, 3, General.Female):addSkills { "guose", "liuli" }
General:new(extension, "luxun", "wu", 3):addSkills { "qianxun", "lianying" }
General:new(extension, "sunshangxiang", "wu", 3, 3, General.Female):addSkills { "xiaoji", "jieyin" }

General:new(extension, "huatuo", "qun", 3):addSkills { "qingnang", "jijiu" }
General:new(extension, "lvbu", "qun", 4):addSkills { "wushuang" }
General:new(extension, "diaochan", "qun", 3, 3, General.Female):addSkills { "lijian", "biyue" }

local role_getlogic = function()
  local role_logic = GameLogic:subclass("role_logic")

--- 分配身份
  function role_logic:assignRoles()
    local room = self.room
    local n = #room.players
    local roles = self.role_table[n]

    local rebel_index = table.indexOf(roles, "rebel")
    if rebel_index then
      if room:getSettings("MakeCivilian") then
        table.remove(roles, rebel_index)
        table.insert(roles, rebel_index, "civilian")
      elseif room:getSettings("DoubleRenegade") then
        table.remove(roles, rebel_index)
        table.insert(roles, rebel_index, "renegade")
      end
    end

    room:shuffleTable(roles)

    local roomLordID = table.findIndex(room.players, function(p) return p.id > 0 end)
    local roomRole = room:getSettings("LordIsWhat")
    local roomRoleIndex = table.indexOf(roles, roomRole)
    if roomRole ~= "False" and math.min(roomLordID, roomRoleIndex) ~= -1 then
      roles[roomLordID], roles[roomRoleIndex] = roles[roomRoleIndex], roles[roomLordID]
    end

    room:quickSetPlayerRole(roles)

    for i = 1, n do
      local p = room.players[i]
      p.role = roles[i]
      if p.role == "lord" then
        room:setPlayerProperty(p, "role_shown", true)
      end
      room:broadcastProperty(p, "role")
    end
  end

  function role_logic:chooseGenerals()
    local room = self.room ---@class Room
    local generalNum = room:getSettings('generalNum')
    local lord = room:getLord()
    local lord_num = 3

    if lord ~= nil then
      room:setCurrent(lord)

      -- 快速设置
      local quickSetPlayers = room:quickSetPlayerGeneral()

      local a1 = #room.general_pile
      local a2 = #room.players * generalNum
      if a1 < a2 then
        room:sendLog{
          type = "#NoEnoughGeneralDraw",
          arg = a1,
          arg2 = a2,
          toast = true,
        }
        room:gameOver("")
      end
      lord_num = math.min(a1 - a2, lord_num)
      local generals = table.connect(room:findGenerals(function(g)
        return table.contains(Fk.lords, g)
      end, lord_num), room:getNGenerals(generalNum))

      if not table.contains(quickSetPlayers, lord) then
        room:askToChooseIniticalGeneral(lord, {
          targets = lord,
          generals = generals,
          needDeputy = room:getSettings("enableDeputy"),
          returnPile = true,
        })
      end

      room:broadcastProperty(lord, "kingdom")

      -- 显示技能
      local canAttachSkill = function(player, skillName)
        local skill = Fk.skills[skillName]
        if not skill then
          fk.qCritical("Skill: "..skillName.." doesn't exist!")
          return false
        end
        if skill:hasTag(Skill.Lord) and not (player.role == "lord" and player.role_shown and room:isGameMode("role_mode")) then
          return false
        end

        if skill:hasTag(Skill.AttachedKingdom) and not table.contains(skill:getSkeleton().attached_kingdom, player.kingdom) then
          return false
        end

        return true
      end

      local lord_skills = {}
      for _, s in ipairs(Fk.generals[lord.general].skills) do
        if canAttachSkill(lord, s.name) then
          table.insertIfNeed(lord_skills, s.name)
        end
      end
      for _, sname in ipairs(Fk.generals[lord.general].other_skills) do
        if canAttachSkill(lord, sname) then
          table.insertIfNeed(lord_skills, sname)
        end
      end

      local deputyGeneral = Fk.generals[lord.deputyGeneral]
      if deputyGeneral then
        for _, s in ipairs(deputyGeneral.skills) do
          if canAttachSkill(lord, s.name) then
            table.insertIfNeed(lord_skills, s.name)
          end
        end
        for _, sname in ipairs(deputyGeneral.other_skills) do
          if canAttachSkill(lord, sname) then
            table.insertIfNeed(lord_skills, sname)
          end
        end
      end

      for _, skill in ipairs(lord_skills) do
        room:doBroadcastNotify("AddSkill", { lord.id, skill })
      end

      if room:getSettings("WangzhanFourEmblems") then
        local emblems = { "qinglong_emblem&", "baihu_emblem&", "zhuque_emblem&", "xuanwu_emblem&" }
        local skill = room:tableRandomPick(emblems)
        table.removeOne(emblems, skill)
        room:setBanner("WangzhanFourEmblems", emblems)
        room:handleAddLoseSkills(lord, skill, nil, false, true)
      end

      if room:getSettings("DesignateHeir") then
        room:addFakeSkill(lord, "lord_designating_heir&")
      end

      local nonlord = table.filter(room:getOtherPlayers(lord, true), function (p)
        return not table.contains(quickSetPlayers, p)
      end)
      if #nonlord > 0 then
        room:askToChooseIniticalGeneral(lord, {
          targets = nonlord,
          num = generalNum,
          needDeputy = room:getSettings("enableDeputy"),
          lordGeneral = lord.general,
          lordDeputy = lord.deputyGeneral,
        })
      end

      local renegade_skills = {} ---@type string[]
      if room:getSettings("RenegadeLoyalty") then table.insert(renegade_skills, "renegade_loyalty&") end
      if room:getSettings("RenegadeWild") then table.insert(renegade_skills, "renegade_wild&") end
      if next(renegade_skills) then
        for _, p in ipairs(nonlord) do
          if p.role == "renegade" then
            table.forEach(renegade_skills, function(s) room:addFakeSkill(p, s) end)
          end
        end
      end
    else
      room:gameOver("")
    end
  end

  return role_logic
end

local role_mode = fk.CreateGameMode{
  name = "aaa_role_mode", -- just to let it at the top of list
  minPlayer = 2,
  maxPlayer = 8,
  logic = role_getlogic,
  main_mode = "role_mode",
  is_counted = function(self, room)
    return #room.players >= 5
  end,
  friend_enemy_judge = function (self, targetOne, targetTwo)
    if targetOne == targetTwo then return true end
    if targetOne.role == "renegade" and targetTwo.role == "renegade" then
      return Fk:currentRoom():getSettings("RenegadeTogether") -- 内奸是否需要内讧
    end
    if targetOne.role == "wild" or targetTwo.role == "wild" then return false end
    return GameMode.friendEnemyJudge(self, targetOne, targetTwo)
  end,
  winner_getter = function(self, victim)
    if not victim.surrendered and victim.rest > 0 then
      return ""
    end

    local room = victim.room
    local winner = ""
    local alive = table.filter(room.players, function(p)
      return not p.surrendered and not (p.dead and p.rest == 0) and p.role ~= "civilian"
    end)

    if #alive == 1 then
      return alive[1]:getFriends(true, true)
    end

    if victim.role == "lord" then
      if table.find(alive, function(p) return p.role == "lord" end) then
        winner = ""
      elseif room:getSettings("RenegadeTogether") and table.every(alive, function(p) return p.role == "renegade" end) then
        winner = "renegade"
      else
        winner = "rebel+rebel_chief"
      end
    elseif victim.role ~= "loyalist" then
      local lord_win = true
      for _, p in ipairs(alive) do
        if p.role == "rebel" or p.role == "rebel_chief" or p.role == "renegade" or p.role == "wild" then
          lord_win = false
          break
        end
      end
      if lord_win then
        winner = "lord+loyalist"
      end
    end

    if winner ~= "" then
      winner = winner.. "+civilian"
      return table.filter(room.players, function (p)
        return table.contains(winner:split("+"), p.role)
      end)
    end
    return ""
  end,
  surrender_func = function(self, playedTime, player)
    if player.role == "loyalist" or player.role == "civilian" then
      return { { text = player.role.." never surrender", passed = false } }
    end

    local alive_players = table.filter(Fk:currentRoom().players, function(p)
      return not p.dead or p.rest > 0
    end)
    local roleText = "left you alive"
    local roleCheck = false
    if #alive_players <= 2 then
      roleCheck = true
    else
      local other = nil ---@type Player
      for _, p in ipairs(alive_players) do
        if p ~= player then
          other = p
          break
        end
      end
      if other and not other:isFriend(player) then
        local non_friend_count = 0
        for _, t in ipairs(alive_players) do
          if not other:isFriend(t) then
            non_friend_count = non_friend_count + 1

            if non_friend_count > 1 then
              break
            end
          end
        end
        roleCheck = (non_friend_count == 1) -- onlyYou
      end
    end

    return {
      { text = "time limitation: 5 min", passed = playedTime >= 300 },
      { text = roleText, passed = roleCheck },
    }
  end,
}

local W = require "ui_emu.preferences"
role_mode.ui_settings = {
  W.PreferenceGroup {
    title = "role_misc_change",

    W.ComboRow {
      _settingsKey = "LordIsWhat",
      title = "LordIsWhat",
      model = { "False", "lord", "loyalist", "rebel", "renegade" }
    },
  },

  W.PreferenceGroup {
    title = "m_wangzhan_enhance",

    W.SwitchRow {
      _settingsKey = "WangzhanBattleRoyal",
      title = "WangzhanBattleRoyal",
    },

    W.SwitchRow {
      _settingsKey = "WangzhanFourEmblems",
      title = "WangzhanFourEmblems",
    },
  },

  W.PreferenceGroup {
    title = "mobile_role_change",

    W.SwitchRow {
      _settingsKey = "DesignateHeir",
      title = "DesignateHeir",
      enabled = function(settings)
        return (settings.playerNum or 0) >= 8
      end,
    },

    W.SwitchRow {
      _settingsKey = "RenegadeLoyalty",
      title = "RenegadeLoyalty",
      enabled = function(settings)
        return (settings.playerNum or 0) >= 8
      end,
    },

    W.SwitchRow {
      _settingsKey = "RenegadeWild",
      title = "RenegadeWild",
      enabled = function(settings)
        return (settings.playerNum or 0) >= 8
      end,
    },
  },

  W.PreferenceGroup {
    title = "role_double_renegade",

    W.SwitchRow {
      _settingsKey = "MakeCivilian",
      title = "MakeCivilian",
      enabled = function(settings)
        return (settings.playerNum or 0) > 5 and settings._mode["DoubleRenegade"] == false
      end,
    },

    W.SwitchRow {
      _settingsKey = "DoubleRenegade",
      title = "DoubleRenegade",
      enabled = function(settings)
        return (settings.playerNum or 0) > 5 and settings._mode["MakeCivilian"] == false
      end,
    },

    W.SwitchRow {
      _settingsKey = "RenegadeTogether",
      title = "RenegadeTogether",
      enabled = function(settings)
        return (settings.playerNum or 0) > 5 and settings._mode["DoubleRenegade"] == true
      end
    },
  },
}

extension:addGameMode(role_mode)
Fk:loadTranslationTable{
  ["time limitation: 5 min"] = "游戏时长达到5分钟",
  ["left you alive"] = "你的阵营仅剩你存活且其他阵营仅剩一方",
  ["loyalist never surrender"] = "忠臣永不投降！",
  ["civilian never surrender"] = "平民坚持就是成功！",

  ["role_misc_change"] = "身份小改动",
  ["LordIsWhat"] = "真人特定身份",
  ["help: LordIsWhat"] = "最早加入房间的真人始终是特定身份（调试用）",

  ["m_wangzhan_enhance"] = "王战比赛规则",
  ["WangzhanBattleRoyal"] = "鏖战",
  ["help: WangzhanBattleRoyal"] = "8人/6人局第3/4轮结束时进入鏖战，回合结束时需弃牌或失去体力",
  ["WangzhanFourEmblems"] = "四象标记",
  ["help: WangzhanFourEmblems"] = "主公开局随机获得一个四象标记(一次性技能)",
  ["@[:]WangzhanBattleRoyal"] = "",
  [":WangzhanBattleRoyal"] = "每回合所有行动结束后，当前回合角色须选择一项：1.将两张牌置入弃牌堆；2.失去1点体力。结算中当前回合角色不触发任何武将技能。",

  ["mobile_role_change"] = "手杀身份规则",
  ["help: mobile_role_change"] = "仅在游戏人数8时有效",
  ["DesignateHeir"] = "主公立储",
  ["help: DesignateHeir"] = "第一轮限一次，主公可以对一名其他角色立储：" ..
      "主公死亡时，若储君为忠臣，获得主公区域内至多两张牌，增加1点体力上限，回复1点体力，变为主公；" ..
      "忠臣储君死亡时，主公失去1点体力；储君杀死主公弃置所有牌。",
  ["RenegadeLoyalty"] = "内奸侍奉明主",
  ["help: RenegadeLoyalty"] = "场上人数＞4且有主忠死亡时，内奸可以变为忠臣（不暴露身份）。",
  ["RenegadeWild"] = "内奸自立",
  ["help: RenegadeWild"] = "内奸可以成为野心家：获得野心家标记（出牌阶段，弃置以摸两张牌或回复1点体力）" ..
      "和〖飞扬〗〖跋扈〗，杀死角色摸三张牌。",

  ["role_double_renegade"] = "双内模式相关",
  ["help: role_double_renegade"] = "仅在游戏人数<b>不小于6</b>时有效",
  ["MakeCivilian"] = "置入平民",
  ["help: MakeCivilian"] = "将最后一个反贼替换为平民，平民只要存活就能胜利",
  ["DoubleRenegade"] = "双内奸",
  ["help: DoubleRenegade"] = "将最后一个反贼替换为内奸",
  ["RenegadeTogether"] = "内奸同阵营",
  ["help: RenegadeTogether"] = "不要求内奸杀死其余所有内奸才能胜利",
}

local anjiang = General(extension, "anjiang", "unknown", 5)
anjiang.gender = General.Agender
anjiang.total_hidden = true

Fk:loadTranslationTable{
  ["anjiang"] = "暗将",
}


return extension
