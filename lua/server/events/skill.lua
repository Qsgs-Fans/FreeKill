-- SPDX-License-Identifier: GPL-3.0-or-later

---@class SkillEventWrappers: Object
local SkillEventWrappers = {} -- mixin

---@return boolean
local function exec(tp, ...)
  local event = tp:create(...)
  local _, ret = event:exec()
  return ret
end

---@class GameEvent.SkillEffect : GameEvent
---@field public data SkillEffectData
local SkillEffect = GameEvent:subclass("GameEvent.SkillEffect")
function SkillEffect:main()
  local data = self.data
  local effect_cb, player, skill, skill_data = data.skill_cb, data.who, data.skill, data.skill_data
  local room = self.room
  local logic = room.logic
  local main_skill = skill.main_skill and skill.main_skill or skill
  skill_data = skill_data or Util.DummyTable
  local cost_data = skill_data.cost_data or Util.DummyTable

  if player and not skill.cardSkill then
    player:revealBySkillName(main_skill.name)

    local tos = skill_data.tos and table.map(skill_data.tos, Util.IdMapper) or {}
    local mute, no_indicate = skill.mute, skill.no_indicate
    if type(cost_data) == "table" then
      if cost_data.mute then mute = cost_data.mute end
      if cost_data.no_indicate then no_indicate = cost_data.no_indicate end
    end
    if not mute then
      if skill.attached_equip then
        local equip = Fk.all_card_types[skill.attached_equip]
        if equip then
          local pkgPath = "./packages/" .. equip.package.extensionName
          local soundName = pkgPath .. "/audio/card/" .. equip.name
          room:broadcastPlaySound(soundName)
          if not no_indicate and #tos > 0 then
            room:sendLog{
              type = "#InvokeSkillTo",
              from = player.id,
              arg = skill.name,
              to = tos,
            }
          else
            room:sendLog{
              type = "#InvokeSkill",
              from = player.id,
              arg = skill.name,
            }
          end
          room:setEmotion(player, pkgPath .. "/image/anim/" .. equip.name)
        end
      else
        player:broadcastSkillInvoke(skill.name)
        room:notifySkillInvoked(player, skill.name, nil, no_indicate and {} or tos)
      end
    end
    if not no_indicate then
      room:doIndicate(player.id, tos)
    end

    if skill:isSwitchSkill() then
      local switchSkillName = skill.switchSkillName
      room:setPlayerMark(
        player,
        MarkEnum.SwithSkillPreName .. switchSkillName,
        player:getSwitchSkillState(switchSkillName, true)
      )
    end

    player:addSkillUseHistory(main_skill.name)
  end

  local cost_data_bak = skill.cost_data
  logic:trigger(fk.SkillEffect, player, main_skill)
  skill.cost_data = cost_data_bak

  local ret = effect_cb and effect_cb() or false
  logic:trigger(fk.AfterSkillEffect, player, main_skill)
  return ret
end

--- 使用技能。先增加技能发动次数，再执行相应的函数。
---@param player ServerPlayer @ 发动技能的玩家
---@param skill Skill @ 发动的技能
---@param effect_cb fun() @ 实际要调用的函数
---@param skill_data? table @ 技能的信息
function SkillEventWrappers:useSkill(player, skill, effect_cb, skill_data)
  if skill_data then
    for k, v in pairs(skill_data) do
      if table.contains({"from"}, k) and type(v) == "number" then
        skill_data[k] = self:getPlayerById(v)
      elseif table.contains({"tos"}, k) and type(v[1]) == "number" then
        local new_v = {}
        for _, pid in ipairs(v) do
          table.insert(new_v, self:getPlayerById(pid))
        end
        skill_data[k] = new_v
      else
        skill_data[k] = v
      end
    end
  end
  local data = SkillEffectData:new{
    who = player,
    skill = skill,
    skill_cb = effect_cb,
    skill_data = skill_data
  }
  return exec(SkillEffect, data)
end

--- 令一名玩家获得/失去技能。
---
--- skill_names 是字符串数组或者用管道符号(|)分割的字符串。
---
--- 每个skill_name都是要获得的技能的名。如果在skill_name前面加上"-"，那就是失去技能。
---@param player ServerPlayer @ 玩家
---@param skill_names string[] | string @ 要获得/失去的技能
---@param source_skill? string | Skill @ 源技能
---@param no_trigger? boolean @ 是否不触发相关时机
function SkillEventWrappers:handleAddLoseSkills(player, skill_names, source_skill, sendlog, no_trigger)
  if type(skill_names) == "string" then
    skill_names = skill_names:split("|")
  end

  if sendlog == nil then sendlog = true end

  if #skill_names == 0 then return end
  local losts = {}  ---@type boolean[]
  local triggers = {} ---@type Skill[]
  -- local lost_piles = {} ---@type integer[]
  for _, skill in ipairs(skill_names) do
    if string.sub(skill, 1, 1) == "-" then
      local actual_skill = string.sub(skill, 2, #skill)
      if player:hasSkill(actual_skill, true, true) then
        local lost_skills = player:loseSkill(actual_skill, source_skill)
        for _, s in ipairs(lost_skills) do
          self:doBroadcastNotify("LoseSkill", json.encode{
            player.id,
            s.name
          })

          if sendlog and s.visible then
            self:sendLog{
              type = "#LoseSkill",
              from = player.id,
              arg = s.name
            }
          end

          table.insert(losts, true)
          table.insert(triggers, s)
          -- if s.derived_piles then
          --   for _, pile_name in ipairs(s.derived_piles) do
          --     table.insertTableIfNeed(lost_piles, player:getPile(pile_name))
          --   end
          -- end

          self:validateSkill(player, actual_skill)
          for _, suf in ipairs(MarkEnum.TempMarkSuffix) do
            self:validateSkill(player, actual_skill, suf)
          end
        end
      end
    else
      local sk = Fk.skills[skill]
      if sk and not player:hasSkill(sk, true, true) then
        local got_skills = player:addSkill(sk, source_skill)

        for _, s in ipairs(got_skills) do
          -- TODO: limit skill mark

          self:doBroadcastNotify("AddSkill", json.encode{
            player.id,
            s.name
          })

          if sendlog and s.visible then
            self:sendLog{
              type = "#AcquireSkill",
              from = player.id,
              arg = s.name
            }
          end

          table.insert(losts, false)
          table.insert(triggers, s)
        end
      end
    end
  end

  if (not no_trigger) and #triggers > 0 then
    for i = 1, #triggers do
      if losts[i] then
        local skill = triggers[i]
        skill:onLose(player)
        self.logic:trigger(fk.EventLoseSkill, player, skill)
      else
        local skill = triggers[i]
        self.logic:trigger(fk.EventAcquireSkill, player, skill)
        skill:onAcquire(player)
      end
    end
  end

  -- if #lost_piles > 0 then
  --   self:moveCards({
  --     ids = lost_piles,
  --     from = player.id,
  --     toArea = Card.DiscardPile,
  --     moveReason = fk.ReasonPutIntoDiscardPile,
  --   })
  -- end
end

return { SkillEffect, SkillEventWrappers }
