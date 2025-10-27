-- SPDX-License-Identifier: GPL-3.0-or-later

---@class MiscEventWrappers: Object
local MiscEventWrappers = {} -- mixin

---@class GameEvent.ChangeProperty : GameEvent
---@field public data PropertyChangeData
local ChangeProperty = GameEvent:subclass("GameEvent.Game")

function ChangeProperty:__tostring()
  return string.format("<ChangeProperty %s #%d>", self.data.from, self.id)
end

function ChangeProperty:main()
  local data = self.data
  local room = self.room
  local player = data.from
  local logic = room.logic
  logic:trigger(fk.BeforePropertyChange, player, data)

  data.sendLog = data.sendLog or false
  local skills = {}
  if logic:trigger(fk.PropertyChange, player, data) then
    logic:breakEvent()
  end

  local isLord = (player.role == "lord" and player.role_shown) and room:isGameMode("role_mode")
  if data.general and data.general ~= "" and data.general ~= player.general then
    local originalGeneral = Fk.generals[player.general] or Fk.generals["blank_shibing"]
    local originalSkills = originalGeneral and originalGeneral:getSkillNameList(true) or Util.DummyTable
    table.insertTableIfNeed(skills, table.map(originalSkills, function(e)
      return "-" .. e
    end))
    local newGeneral = Fk.generals[data.general] or Fk.generals["blank_shibing"]
    for _, name in ipairs(newGeneral:getSkillNameList(isLord)) do
      local s = Fk.skills[name]
      if not s:hasTag(Skill.DeputyPlace) then
        table.insertIfNeed(skills, name)
      end
    end
    if data.sendLog then
      room:sendLog{
        type = "#ChangeHero",
        from = player.id,
        arg = player.general,
        arg2 = data.general,
        arg3 = "mainGeneral",
      }
    end
    data.results["generalChange"] = {player.general, data.general}
    room:setPlayerProperty(player, "general", data.general)
  end

  if data.deputyGeneral and data.deputyGeneral ~= player.deputyGeneral then
    local originalDeputy = Fk.generals[player.deputyGeneral] or Fk.generals["blank_shibing"]
    local originalSkills = originalDeputy and originalDeputy:getSkillNameList(true) or Util.DummyTable
    table.insertTableIfNeed(skills, table.map(originalSkills, function(e)
      return "-" .. e
    end))

    if data.deputyGeneral ~= "" then
      local newDeputy = Fk.generals[data.deputyGeneral] or Fk.generals["blank_shibing"]
      for _, name in ipairs(newDeputy:getSkillNameList(isLord)) do
        local s = Fk.skills[name]
        if not s:hasTag(Skill.MainPlace) then
          table.insertIfNeed(skills, name)
        end
      end

      if data.sendLog then
        room:sendLog{
          type = "#ChangeHero",
          from = player.id,
          arg = player.deputyGeneral,
          arg2 = data.deputyGeneral,
          arg3 = "deputyGeneral",
        }
      end
    end

    data.results["deputyChange"] = {player.deputyGeneral, data.deputyGeneral}
    room:setPlayerProperty(player, "deputyGeneral", data.deputyGeneral)
  end

  if data.gender and data.gender ~= player.gender then
    data.results["genderChange"] = {player.gender, data.gender}
    room:setPlayerProperty(player, "gender", data.gender)
  end

  if data.kingdom and data.kingdom ~= "" and data.kingdom ~= player.kingdom then
    if data.sendLog then
      room:sendLog{
        type = "#ChangeKingdom",
        from = player.id,
        arg = player.kingdom,
        arg2 = data.kingdom,
      }
    end
    data.results["kingdomChange"] = {player.kingdom, data.kingdom}
    room:setPlayerProperty(player, "kingdom", data.kingdom)
  end

  local skillsAttachedKingdom = Fk.generals[player.general]:getSkillNameList(isLord)
  if player.deputyGeneral ~= "" then
    table.insertTableIfNeed(skillsAttachedKingdom, Fk.generals[player.deputyGeneral]:getSkillNameList(isLord))
  end
  for _, sname in ipairs(skillsAttachedKingdom) do
    local s = Fk.skills[sname]
    if s:hasTag(Skill.AttachedKingdom) then
      if table.contains(s:getSkeleton().attached_kingdom, player.kingdom) then
        table.insertIfNeed(skills, s.name)
      else
        if table.contains(skills, s.name) then
          table.removeOne(skills, s.name)
        else
          table.insertIfNeed(skills, "-"..s.name)
        end
      end
    end
  end
  room:handleAddLoseSkills(player, table.concat(skills, "|"), nil, false, false)

  logic:trigger(fk.AfterPropertyChange, player, data)
end

--- 改变角色的武将
---@param player ServerPlayer @ 要换将的玩家
---@param new_general string @ 要变更的武将，若不存在则变身为孙策，孙策不存在变身为士兵
---@param full? boolean @ 是否血量满状态变身，默认否
---@param isDeputy? boolean @ 是否变的是副将
---@param sendLog? boolean @ 是否发Log，默认否
---@param maxHpChange? boolean @ 是否改变体力上限，默认改变
---@param kingdomChange? boolean @ 是否改变势力（仅更改主将时变更），默认改变
function MiscEventWrappers:changeHero(player, new_general, full, isDeputy, sendLog, maxHpChange, kingdomChange)
  local new = Fk.generals[new_general] or Fk.generals["sunce"] or Fk.generals["blank_shibing"]
  ---@cast self Room
  kingdomChange = (kingdomChange == nil) and true or kingdomChange
  local kingdom = (isDeputy or not kingdomChange) and player.kingdom or new.kingdom
  if not isDeputy and kingdomChange then
    local allKingdoms = {}
    if new.subkingdom then
      allKingdoms = { new.kingdom, new.subkingdom }
    else
      allKingdoms = Fk:getKingdomMap(new.kingdom)
    end
    if #allKingdoms > 0 then
      kingdom = self:askToChoice(player, { choices = allKingdoms, skill_name = "AskForKingdom", prompt = "#ChooseInitialKingdom" })
    end
  end

  ChangeProperty:create(PropertyChangeData:new{
    from = player,
    general = not isDeputy and new_general or nil,
    deputyGeneral = isDeputy and new_general or nil,
    gender = isDeputy and player.gender or new.gender,
    kingdom = kingdom,
    sendLog = sendLog,
    results = {},
  }):exec()

  local oldHp, oldMaxHp = player.hp, player.maxHp
  if (maxHpChange == nil) or maxHpChange then
    local maxHp = player:getGeneralMaxHp()
    local changer = Fk.game_modes[self:getSettings('gameMode')]:getAdjustedProperty(player)
    if changer and changer.maxHp then
      maxHp = maxHp + (changer.maxHp - player.maxHp)
    end
    self:setPlayerProperty(player, "maxHp", maxHp)
  end
  if full or player.hp > player.maxHp then
    self:setPlayerProperty(player, "hp", player.maxHp)
  end
  if oldHp ~= player.hp or oldMaxHp ~= player.maxHp then
    self:sendLog{
      type = "#ShowHPAndMaxHP",
      from = player.id,
      arg = player.hp,
      arg2 = player.maxHp,
    }
  end
end

---@param player ServerPlayer @ 要变更势力的玩家
---@param kingdom string @ 要变更的势力
---@param sendLog? boolean @ 是否发Log
function MiscEventWrappers:changeKingdom(player, kingdom, sendLog)
  if kingdom == player.kingdom then return end
  sendLog = sendLog or false

  ChangeProperty:create(PropertyChangeData:new{
    from = player,
    kingdom = kingdom,
    sendLog = sendLog,
    results = {},
  }):exec()
end

return { ChangeProperty, MiscEventWrappers }
