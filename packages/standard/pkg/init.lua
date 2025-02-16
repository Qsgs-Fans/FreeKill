local extension = Package:new("standard")

local prefix = "packages."
if UsingNewCore then prefix = "packages.freekill-core." end

extension:loadSkillSkels(require(prefix .. "standard.pkg.skills"))

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

  function role_logic:chooseGenerals()
    local room = self.room ---@class Room
    local generalNum = room.settings.generalNum
    local n = room.settings.enableDeputy and 2 or 1
    local lord = room:getLord()
    local lord_generals = {}
    local lord_num = 3

    if lord ~= nil then
      room:setCurrent(lord)
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
      lord_generals = room:askForGeneral(lord, generals, n)
      local lord_general, deputy
      if type(lord_generals) == "table" then
        deputy = lord_generals[2]
        lord_general = lord_generals[1]
      else
        lord_general = lord_generals
        lord_generals = {lord_general}
      end
      generals = table.filter(generals, function(g)
        return not table.find(lord_generals, function(lg)
          return Fk.generals[lg].trueName == Fk.generals[g].trueName
        end)
      end)
      room:returnToGeneralPile(generals)

      room:prepareGeneral(lord, lord_general, deputy, true)

      room:askForChooseKingdom({lord})
      room:broadcastProperty(lord, "kingdom")

      -- 显示技能
      local canAttachSkill = function(player, skillName)
        local skill = Fk.skills[skillName]
        if not skill then
          fk.qCritical("Skill: "..skillName.." doesn't exist!")
          return false
        end
        if skill.lordSkill and (player.role ~= "lord" or #room.players < 5) then
          return false
        end

        if #skill.attachedKingdom > 0 and not table.contains(skill.attachedKingdom, player.kingdom) then
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
        room:doBroadcastNotify("AddSkill", json.encode{
          lord.id,
          skill
        })
      end
    end

    local nonlord = room:getOtherPlayers(lord, true)
    local req = Request:new(nonlord, "AskForGeneral")
    local generals = table.random(room.general_pile, #nonlord * generalNum)
    for i, p in ipairs(nonlord) do
      local arg = table.slice(generals, (i - 1) * generalNum + 1, i * generalNum + 1)
      req:setData(p, { arg, n })
      req:setDefaultReply(p, table.random(arg, n))
    end

    for _, p in ipairs(nonlord) do
      local result = req:getResult(p)
      local general, deputy = result[1], result[2]
      room:findGeneral(general)
      room:findGeneral(deputy)
      room:prepareGeneral(p, general, deputy)
    end

    room:askForChooseKingdom(nonlord)
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
  surrender_func = function(self, playedTime)
    local roleCheck = false
    local roleText = ""
    local roleTable = {
      { "lord" },
      { "lord", "rebel" },
      { "lord", "rebel", "renegade" },
      { "lord", "loyalist", "rebel", "renegade" },
      { "lord", "loyalist", "rebel", "rebel", "renegade" },
      { "lord", "loyalist", "rebel", "rebel", "rebel", "renegade" },
      { "lord", "loyalist", "loyalist", "rebel", "rebel", "rebel", "renegade" },
      { "lord", "loyalist", "loyalist", "rebel", "rebel", "rebel", "rebel", "renegade" },
    }

    roleTable = roleTable[#Fk:currentRoom().players]

    if Self.role == "renegade" then
      local rebelNum = #table.filter(roleTable, function(role)
        return role == "rebel"
      end)

      for _, p in ipairs(Fk:currentRoom().players) do
        if p.role == "rebel" then
          if not p.dead then
            break
          else
            rebelNum = rebelNum - 1
          end
        end
      end

      roleCheck = rebelNum == 0
      roleText = "left lord and loyalist alive"
    elseif Self.role == "rebel" then
      local rebelNum = #table.filter(roleTable, function(role)
        return role == "rebel"
      end)

      local renegadeDead = not table.find(roleTable, function(role)
        return role == "renegade"
      end)
      for _, p in ipairs(Fk:currentRoom().players) do
        if p.role == "renegade" and p.dead then
          renegadeDead = true
        end

        if p ~= Self and p.role == "rebel" then
          if not p.dead then
            break
          else
            rebelNum = rebelNum - 1
          end
        end
      end

      roleCheck = renegadeDead and rebelNum == 1
      roleText = "left one rebel alive"
    else
      if Self.role == "loyalist" then
        return { { text = "loyalist never surrender", passed = false } }
      else
        if #Fk:currentRoom().alive_players == 2 then
          roleCheck = true
        else
          local lordNum = #table.filter(roleTable, function(role)
            return role == "lord" or role == "loyalist"
          end)

          local renegadeDead = not table.find(roleTable, function(role)
            return role == "renegade"
          end)
          for _, p in ipairs(Fk:currentRoom().players) do
            if p.role == "renegade" and p.dead then
              renegadeDead = true
            end

            if p ~= Self and (p.role == "lord" or p.role == "loyalist") then
              if not p.dead then
                break
              else
                lordNum = lordNum - 1
              end
            end
          end

          roleCheck = renegadeDead and lordNum == 1
        end
      end

      roleText = "left you alive"
    end

    return {
      { text = "time limitation: 5 min", passed = playedTime >= 300 },
      { text = roleText, passed = roleCheck },
    }
  end,
}
extension:addGameMode(role_mode)
Fk:loadTranslationTable{
  ["time limitation: 5 min"] = "游戏时长达到5分钟",
  ["left lord and loyalist alive"] = "仅剩你和主忠方存活",
  ["left one rebel alive"] = "反贼仅剩你存活且不存在存活内奸",
  ["left you alive"] = "主忠方仅剩你存活且其他阵营仅剩一方",
  ["loyalist never surrender"] = "忠臣永不投降！",
}

local anjiang = General(extension, "anjiang", "unknown", 5)
anjiang.gender = General.Agender
anjiang.total_hidden = true

Fk:loadTranslationTable{
  ["anjiang"] = "暗将",
}


return extension
