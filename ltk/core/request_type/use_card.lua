local ReqActiveSkill = require 'ltk.core.request_type.active_skill'
local ReqResponseCard = require 'ltk.core.request_type.response_card'

---@class ReqUseCard: ReqResponseCard
local ReqUseCard = ReqResponseCard:subclass("ReqUseCard")

function ReqUseCard:updatePrompt()
  if self.skill_name then
    return ReqActiveSkill.updatePrompt(self)
  end
  local card = self.selected_card
  if card and card:getSkill(self.player) then
    self:setSkillPrompt(card:getSkill(self.player), {card.id})
  else
    self:setPrompt(self.original_prompt or "")
  end
end

function ReqUseCard:skillButtonValidity(name)
  if self.sub_selection_flag then return false end -- 处于二级选择时不允许切换技能
  local player = self.player
  local skill = Fk.skills[name]---@cast skill ViewAsSkill
  return
    skill:isInstanceOf(ViewAsSkill) and
    skill:enabledAtResponse(player, false) and
    skill.pattern and
    Exppattern:Parse(self.pattern):matchExp(skill.pattern) and
    not table.contains(self.disabledSkillNames or {}, name)
end

--- 一张牌能否被点亮（包括正在被点选的实体牌）
---@param cid integer|Card
---@return boolean
function ReqUseCard:cardValidity(cid)
  if self.skill_name then return ReqActiveSkill.cardValidity(self, cid) end
  local card = cid
  if type(cid) == "number" then card = Fk:getCardById(cid) end
  return not not self:cardFeasible(card)
end

function ReqUseCard:targetValidity(pid)
  if self.skill_name then
    -- 本部分只在fix_user处进行改造，其他与ReqActiveSkill同名方法一致
    local skill = Fk.skills[self.skill_name] --[[@as ActiveSkill | ViewAsSkill]]
    if not skill then return false end
    local card -- 承接参数用
    local user = self.player
    if skill:isInstanceOf(ViewAsSkill) then
      ---@cast skill ViewAsSkill
      card = self:getUsingCard()
      --不要在当前转化卡牌不可用的情况下开启选目标
      if card and self:cardFeasible(card) then
        skill = card:getSkill(user)
        if self.extra_data and self.extra_data.fix_user then
          user = Fk:currentRoom():getPlayerById(self.extra_data.fix_user)
        end
      end
    end
    local room = Fk:currentRoom()
    local p = room:getPlayerById(pid)
    local selected = table.map(self.selected_targets, Util.Id2PlayerMapper)
    return not not skill:targetFilter(user, p, selected, self.pendings, card, self.extra_data)
  end
  local card = self.selected_card
  local p = Fk:currentRoom():getPlayerById(pid)
  local selected = table.map(self.selected_targets or {}, Util.Id2PlayerMapper)
  local user = self.player
  if self.extra_data and self.extra_data.fix_user then
    user = Fk:currentRoom():getPlayerById(self.extra_data.fix_user)
  end
  local ret = card and card:getSkill(user):targetFilter(user, p, selected, { card.id }, card, self.extra_data)
  return not not ret
end

---@param card Card
function ReqUseCard:cardFeasible(card)
  local exp = Exppattern:Parse(self.pattern or ".")
  local player = self.player
  if self.extra_data and self.extra_data.fix_user then
    player = Fk:currentRoom():getPlayerById(self.extra_data.fix_user)
  end
  if not player:prohibitUse(card) and exp:match(card) then
    return (card.is_passive and not (self.extra_data or Util.DummyTable).not_passive) or player:canUse(card, self.extra_data)
  else
    for _, skill in ipairs(card.special_skills or Util.DummyTable) do
      local s = Fk.skills[skill]  ---@type ViewAsSkill
      if s:isInstanceOf(ViewAsSkill) and s:enabledAtResponse(player) then
        local new_card = s:viewAs(player, { card.id })
        if new_card and
          ((new_card.is_passive and not (self.extra_data or Util.DummyTable).not_passive) or player:canUse(new_card, self.extra_data)) then
          return true
        end
      end
    end
  end
  return false
end

function ReqUseCard:feasible()
  local skill = Fk.skills[self.skill_name]---@cast skill ViewAsSkill
  local card = self:getUsingCard()
  if skill and card == nil and not self.sub_selection_flag then
    local selected = table.map(self.selected_targets, Util.Id2PlayerMapper)
    return skill:feasible(self.player, selected, self.pendings)
  end
  local ret = false
  if card and self:cardFeasible(card) then
    local user = self.player
    if self.extra_data and self.extra_data.fix_user then
      user = Fk:currentRoom():getPlayerById(self.extra_data.fix_user)
    end
    ret = card:getSkill(user):feasible(user, table.map(self.selected_targets, Util.Id2PlayerMapper),
      skill and self.pendings or { card.id }, card)
  end
  return not not ret
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
    local skill = card:getSkill(player)
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
