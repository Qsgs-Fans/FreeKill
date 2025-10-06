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

function SkillEffect:__tostring()
  local effectData = self.data
  local useData = effectData.skill_data
  return string.format("<UseSkill %s: %s => [%s] #%d>",
    effectData.skill.name, effectData.who, table.concat(
      table.map(useData.tos or {}, ServerPlayer.__tostring), ", "), self.id)
end

function SkillEffect:main()
  local data = self.data
  local effect_cb, player, skill, skill_data = data.skill_cb, data.who, data.skill, data.skill_data
  local room = self.room
  local logic = room.logic
  skill_data = skill_data or Util.DummyTable
  local cost_data = skill_data.cost_data or Util.DummyTable

  if player and not skill.cardSkill then
    if not skill.is_delay_effect then -- 延迟效果不亮将
      local main_skill = skill.main_skill and skill.main_skill or skill
      player:revealBySkillName(main_skill.name)
    end

    local tos = skill_data.tos and ---@type integer[]
      table.map(skill_data.tos, function (to)
        if type(to) == "table" then
          return to.id
        else
          return to
        end
      end) or {}
    local mute, no_indicate, audio_index, anim_type = skill.mute, skill.no_indicate, skill.audio_index, skill.anim_type
    if type(cost_data) == "table" then
      if cost_data.mute then mute = cost_data.mute end
      if cost_data.no_indicate then no_indicate = cost_data.no_indicate end
      if cost_data.audio_index then audio_index = cost_data.audio_index end
      if cost_data.anim_type then anim_type = cost_data.anim_type end
    end
    if not mute then
      if skill:getSkeleton().attached_equip then
        local equip = Fk.all_card_types[skill:getSkeleton().attached_equip]
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
      elseif not skill.click_count then
        if type(audio_index) == "table" then
          audio_index = table.random(audio_index)
        end
        player:broadcastSkillInvoke(skill:getSkeleton().name, audio_index)
        room:notifySkillInvoked(player, skill.name, anim_type, no_indicate and {} or tos)
      end
    end
    if not no_indicate then
      room:doIndicate(player.id, tos)
    end

    if skill:hasTag(Skill.Switch) and not skill.is_delay_effect then
      local switchSkillName = skill:getSkeleton().name ---@type string
      room:setPlayerMark(
        player,
        MarkEnum.SwithSkillPreName .. switchSkillName,
        player:getSwitchSkillState(switchSkillName, true)
      )
    end

    local branch
    if type(cost_data) == "table" then
      branch = cost_data.history_branch
    end
    if not branch then
      if type(skill.history_branch) == "function" then
        branch = skill:history_branch(player, skill_data)
      else
        branch = skill.history_branch
      end
    end

    player:addSkillUseHistory(skill.name)
    if not skill.is_delay_effect then
      if skill.name ~= skill:getSkeleton().name then
        player:addSkillUseHistory(skill:getSkeleton().name)

        if branch then
          player:addSkillBranchUseHistory(skill:getSkeleton().name, branch)
        end
      else
        player:addSkillUseHistory("#" .. skill.name .. "_main_skill")
        if branch then
          player:addSkillBranchUseHistory(skill.name, branch)
        end
      end
    end
  end

  logic:trigger(fk.SkillEffect, player, data)
  if not data.prevented then
    if effect_cb then
      data.trigger_break = effect_cb()
    end
  end

  logic:trigger(fk.AfterSkillEffect, player, data)
  return data.trigger_break
end

function SkillEffect:clear()
  self.room:destroyTableCardByEvent(self.id)
end

function SkillEffect:desc()
  local effectData = self.data
  local useData = effectData.skill_data
  local ret = {
    type = (useData.tos and #useData.tos > 0) and "#GameEventSkillTos" or "#GameEventSkill",
    from = effectData.who.id,
    arg = effectData.skill.name,
  }
  if useData.tos and #useData.tos > 0 then
    ret.to = table.map(useData.tos, Util.IdMapper)
  end
  return ret
end

--- 使用技能。先增加技能发动次数，再执行相应的函数。
---@param player ServerPlayer @ 发动技能的玩家
---@param skill Skill @ 发动的技能
---@param effect_cb fun() @ 实际要调用的函数
---@param skill_data? SkillUseDataSpec @ 技能的信息
---@return SkillEffectData
function SkillEventWrappers:useSkill(player, skill, effect_cb, skill_data)
  ---@cast self Room
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
  exec(SkillEffect, data)
  return data
end

--- 令一名玩家获得/失去技能。
---
--- skill_names 是字符串数组或者用管道符号(|)分割的字符串。
---
--- 每个skill_name都是要获得的技能的名。如果在skill_name前面加上"-"，那就是失去技能。
---@param player ServerPlayer @ 玩家
---@param skill_names string[] | string @ 要获得/失去的技能
---@param source_skill? string | Skill @ 源技能
---@param sendlog? boolean @ 是否发送战报，默认发送
---@param no_trigger? boolean @ 是否不触发相关时机
function SkillEventWrappers:handleAddLoseSkills(player, skill_names, source_skill, sendlog, no_trigger)
  ---@cast self Room
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
          self:doBroadcastNotify("LoseSkill", {
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

          -- if s.derived_piles then
          --   for _, pile_name in ipairs(s.derived_piles) do
          --     table.insertTableIfNeed(lost_piles, player:getPile(pile_name))
          --   end
          -- end
        end

        table.insert(losts, true)
        table.insert(triggers, Fk.skills[actual_skill])
        self:validateSkill(player, actual_skill)
        for _, suf in ipairs(MarkEnum.TempMarkSuffix) do
          self:validateSkill(player, actual_skill, suf)
        end
      end
    else
      local sk = Fk.skills[skill]
      if sk and not player:hasSkill(sk, true, true) then
        local got_skills = player:addSkill(sk, source_skill)

        for _, s in ipairs(got_skills) do
          -- TODO: limit skill mark

          self:doBroadcastNotify("AddSkill", {
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
        end

        table.insert(losts, false)
        table.insert(triggers, sk)
      end
    end
  end

  for _, p in ipairs(self.alive_players) do
    p:filterHandcards()
  end

  if #triggers > 0 then
    no_trigger = no_trigger == nil and false or no_trigger
    for i = 1, #triggers do
      if losts[i] then
        local skill = triggers[i]
        if not no_trigger then
          self.logic:trigger(fk.EventLoseSkill, player, {skill = skill, who = player})
        end
        skill:getSkeleton():onLose(player, false)
      else
        local skill = triggers[i]
        if no_trigger then
          skill:getSkeleton():onAcquire(player, player.room:getBanner("RoundCount") == nil)
        else
          self.logic:trigger(fk.EventAcquireSkill, player, {skill = skill, who = player})
          skill:getSkeleton():onAcquire(player, false)
        end
      end
    end
  end
end

return { SkillEffect, SkillEventWrappers }
