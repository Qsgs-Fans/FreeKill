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
    self:setSkillPrompt(card.skill, {self.selected_card.id})
  else
    self:setPrompt(self.original_prompt or "")
  end
end

function ReqUseCard:skillButtonValidity(name)
  local player = self.player
  local skill = Fk.skills[name]---@type ViewAsSkill
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
  local card = self.selected_card
  local p = Fk:currentRoom():getPlayerById(pid)
  local selected = table.map(self.selected_targets, Util.Id2PlayerMapper)
  local ret = card and card.skill:targetFilter(self.player, p, selected, { card.id }, card, self.extra_data)
  return ret
end

---@param card Card
function ReqUseCard:cardFeasible(card)
  local exp = Exppattern:Parse(self.pattern)
  local player = self.player
  if not player:prohibitUse(card) and exp:match(card) then
    return card.is_passive or player:canUse(card, self.extra_data)
  end
  return false
end

function ReqUseCard:feasible()
  local skill = Fk.skills[self.skill_name]---@type ViewAsSkill
  local card = self.selected_card
  if skill then
    card = skill:viewAs(self.player, self.pendings)
  end
  local ret = false
  if card and self:cardFeasible(card) then
    ret = card.skill:feasible(self.player, table.map(self.selected_targets, Util.Id2PlayerMapper),
      skill and self.pendings or { card.id }, card)
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
        local p = Fk:currentRoom():getPlayerById(pid)
        local selected_targets = table.map(self.selected_targets, Util.Id2PlayerMapper)
        ret = skill and skill:targetFilter(player, p, selected_targets, { card.id }, card, data.extra_data)
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
