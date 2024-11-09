local ReqActiveSkill = require 'core.request_type.active_skill'
local ReqResponseCard = require 'core.request_type.response_card'

---@class ReqUseCard: ReqResponseCard
local ReqUseCard = ReqResponseCard:subclass("ReqUseCard")

function ReqUseCard:updatePrompt()
  if self.skill_name then
    return ReqActiveSkill.updatePrompt(self)
  end
  local card = self.selected_card
  if card and card.skill then
    self:setSkillPrompt(card.skill, self.selected_card.id)
  else
    self:setPrompt(self.original_prompt or "")
  end
end

function ReqUseCard:skillButtonValidity(name)
  local player = self.player
  local skill = Fk.skills[name]
  return
    skill:isInstanceOf(ViewAsSkill) and
    skill:enabledAtResponse(player, false) and
    skill.pattern and
    Exppattern:Parse(self.pattern):matchExp(skill.pattern) and
    not table.contains(self.disabledSkillNames or {}, name)
end

function ReqUseCard:cardValidity(cid)
  if self.skill_name then return ReqActiveSkill.cardValidity(self, cid) end
  local card = cid
  if type(cid) == "number" then card = Fk:getCardById(cid) end
  return self:cardFeasible(card)
end

function ReqUseCard:targetValidity(pid)
  if self.skill_name then return ReqActiveSkill.targetValidity(self, pid) end
  local player = self.player
  local room = self.room
  local p = room:getPlayerById(pid)
  local card = self.selected_card
  local ret = card and not player:isProhibited(p, card) and
    card.skill:targetFilter(pid, self.selected_targets, { card.id }, card, self.extra_data)

  if ret and self.extra_data then
    local data = self.extra_data
    if data.exclusive_targets then
      -- target不在exclusive中则不可选择
      ret = table.contains(data.exclusive_targets, pid)
    end
    if ret and data.must_targets then
      -- 若must中有还没被选的且这个target不在must中则不可选择
      if table.find(data.must_targets, function(id)
        return not table.contains(self.selected_targets, id)
      end) and not table.contains(data.must_targets, pid) then
        ret = false
      end
    end
    if ret and data.include_targets then
      -- 若include中全都没选，且target不在include中则不可选择
      if table.every(data.include_targets, function(id)
        return not table.contains(self.selected_targets, id)
      end) and not table.contains(data.include_targets, pid) then
        ret = false
      end
    end
  end
  return ret
end

function ReqUseCard:cardFeasible(card)
  local exp = Exppattern:Parse(self.pattern)
  local player = self.player
  return not player:prohibitUse(card) and exp:match(card)
end

function ReqUseCard:feasible()
  local skill = Fk.skills[self.skill_name]
  local card = self.selected_card
  if skill then
    card = skill:viewAs(self.pendings)
  end
  local ret = false
  if card and self:cardFeasible(card) then
    ret = card.skill:feasible(self.selected_targets,
      skill and self.pendings or { card.id }, self.player, card)
  end
  return ret
end

function ReqUseCard:initiateTargets()
  if self.skill_name then
    return ReqActiveSkill.initiateTargets(self)
  end

  -- 重置
  self.selected_targets = {}
  self.scene:unselectAllTargets()
  self:updateUnselectedTargets()
  self:updateButtons()
end

function ReqUseCard:selectTarget(playerid, data)
  if self.skill_name then
    return ReqActiveSkill.selectTarget(self, playerid, data)
  end

  local player = self.player
  local scene = self.scene
  local selected = data.selected
  local card = self.selected_card
  scene:update("Photo", playerid, data)

  if card then
    local skill = card.skill
    if selected then
      table.insert(self.selected_targets, playerid)
    else
      -- 存储剩余目标
      local previous_targets = table.filter(self.selected_targets, function(id)
        return id ~= playerid
      end)
      self.selected_targets = {}
      for _, pid in ipairs(previous_targets) do
        local ret
        ret = not player:isProhibited(self.room:getPlayerById(pid), card) and skill and
          skill:targetFilter(pid, self.selected_targets,
        { card.id }, card, data.extra_data)
        -- 从头开始写目标
        if ret then
          table.insert(self.selected_targets, pid)
        end
        scene:update("Photo", pid, { selected = not not ret })
      end
    end
  end
  self:updateUnselectedTargets()
  self:updateButtons()
end

function ReqUseCard:selectSkill(skill, data)
  ReqResponseCard.selectSkill(self, skill, data)
  self.selected_targets = {}
  self.scene:unselectAllTargets()
  self:updateUnselectedTargets()
end

function ReqUseCard:update(elemType, id, action, data)
  if elemType == "CardItem" or elemType == "Photo" then
    return ReqActiveSkill.update(self, elemType, id, action, data)
  else --if elemType == "Button" or elemType == "SkillButton" then or interaction
    return ReqResponseCard.update(self, elemType, id, action, data)
  end
end

return ReqUseCard
