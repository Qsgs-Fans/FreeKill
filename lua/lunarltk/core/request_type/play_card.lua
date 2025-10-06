local ReqActiveSkill = require 'lunarltk.core.request_type.active_skill'
local ReqUseCard = require 'lunarltk.core.request_type.use_card'
local SpecialSkills = require 'ui_emu.specialskills'
local Button = (require 'ui_emu.control').Button

--[[
  负责处理出牌阶段空闲时使用牌（包括转化牌）
--]]

---@class ReqPlayCard: ReqUseCard
local ReqPlayCard = ReqUseCard:subclass("ReqPlayCard")

function ReqPlayCard:initialize(player)
  ReqUseCard.initialize(self, player)

  self.original_prompt = "#PlayCard"
  local scene = self.scene
  -- 出牌阶段还要多模拟一个结束按钮
  scene:addItem(Button:new(self.scene, "End"))
  scene:addItem(SpecialSkills:new(self.scene, "1"))
end

function ReqPlayCard:setup()
  ReqUseCard.setup(self)

  self.scene:update("Button", "End", { enabled = true })
end

function ReqPlayCard:cardValidity(cid)
  if self.skill_name and not self.selected_card then return ReqActiveSkill.cardValidity(self, cid) end
  local player = self.player
  local card = cid --[[ @as Card ]]
  if type(cid) == "number" then card = Fk:getCardById(cid) end
  local ret = player:canUse(card)
  if ret then
    local min_target = card.skill:getMinTargetNum(player)
    if min_target > 0 then
      for pid, _ in pairs(self.scene:getAllItems("Photo")) do
        ---@cast pid integer
        local to_select = Fk:currentRoom():getPlayerById(pid)
        if card.skill:targetFilter(player, to_select, {}, {}, card, self.extra_data) then
          return true
        end
      end
      ret = false
    end
  end

  if not ret then
    local skills = card.special_skills
    if not skills then return false end
    for _, skill in ipairs(skills) do
      if Fk.skills[skill]:canUse(player) then
        return true
      end
    end
  end
  return not not ret
end

function ReqPlayCard:skillButtonValidity(name)
  local player = self.player
  local skill = Fk.skills[name]---@type ActiveSkill | ViewAsSkill
  if skill:isInstanceOf(ViewAsSkill) then
    local ret = skill:enabledAtPlay(player)
    if ret then -- 没有pattern，或者至少有一个满足
      local exp = Exppattern:Parse(skill.pattern)
      local cnames = {}
      for _, m in ipairs(exp.matchers) do
        if m.name then
          table.insertTable(cnames, m.name)
        end
        if m.trueName then
          table.insertTable(cnames, m.trueName)
        end
      end

      local extra_data = self.extra_data
      for _, n in ipairs(cnames) do
        local c = Fk:cloneCard(n)
        c:setVSPattern(name, player, nil)
        ret = c.skill:canUse(player, c, extra_data) and not player:prohibitUse(c)
        if ret then break end
      end
    end
    return not not ret
  elseif skill:isInstanceOf(ActiveSkill) then
    return not not skill:canUse(player, nil)
  end
end

function ReqPlayCard:feasible()
  local player = self.player
  local ret = false
  local card
  if self.skill_name then
    local skill = Fk.skills[self.skill_name]
    if skill:isInstanceOf(ActiveSkill) then
      ---@cast skill ActiveSkill
      return ReqActiveSkill.feasible(self)
    else -- viewasskill
      ---@cast skill ViewAsSkill
      card = skill:viewAs(player, self.pendings)
      if card == nil then
        return skill:feasible(player, table.map(self.selected_targets, Util.Id2PlayerMapper), self.pendings)
      end
    end
  else
    card = self.selected_card
  end
  if card then
    local skill = card.skill
    ret = skill:feasible(player, table.map(self.selected_targets, Util.Id2PlayerMapper), { card.id }, card)
    and skill:canUse(player, card, self.extra_data)
    and not player:prohibitUse(card)
  end
  return not not ret
end

function ReqPlayCard:isCancelable()
  if self.skill_name and self.selected_card then return false end
  return ReqUseCard.isCancelable(self)
end

--- 选择一个卡牌特殊技能（如重铸）
---@param data string? @ 特殊技能名，不填为正常使用
function ReqPlayCard:selectSpecialUse(data)
  -- 相当于使用一个以已选牌为pendings的主动技
  if not data or data == "_normal_use" then
    self.skill_name = nil
    self.pendings = nil
    -- self:setSkillPrompt(self.selected_card.skill, self.selected_card:getEffectiveId())
  else
    self.skill_name = data
    self.pendings = Card:getIdList(self.selected_card)
    -- self:setSkillPrompt(Fk.skills[data], self.pendings)
  end
  self:initiateTargets()
end

function ReqPlayCard:doOKButton()
  self.scene:update("SpecialSkills", "1", { skills = {} })
  self.scene:notifyUI()
  if not(self.skill_name and self.selected_card) then
    return ReqUseCard.doOKButton(self)
  end
  local reply = {
    card = self.selected_card:getEffectiveId(),
    targets = self.selected_targets,
    special_skill = self.skill_name
  }
  if ClientInstance then
    ClientInstance:notifyUI("ReplyToServer", reply)
  else
    return reply
  end
end

function ReqPlayCard:doCancelButton()
  self.scene:update("SpecialSkills", "1", { skills = {} })
  self.scene:notifyUI()
  return ReqUseCard.doCancelButton(self)
end

function ReqPlayCard:doEndButton()
  self.scene:update("SpecialSkills", "1", { skills = {} })
  self.scene:notifyUI()
  if ClientInstance then
    ClientInstance:notifyUI("ReplyToServer", "")
  else
    return ""
  end
end

function ReqPlayCard:selectCard(cid, data)
  if self.skill_name and not self.selected_card then
    return ReqActiveSkill.selectCard(self, cid, data)
  end
  local scene = self.scene
  local selected = data.selected
  scene:update("CardItem", cid, data)

  if selected then
    self.skill_name = nil
    self.selected_card = Fk:getCardById(cid)
    scene:unselectOtherCards(cid)
    -- self:setSkillPrompt(self.selected_card.skill, self.selected_card:getEffectiveId())
    local sp_skills = {}
    if self.selected_card.special_skills and table.contains(self.player:getCardIds("h"), cid) then
      sp_skills = table.simpleClone(self.selected_card.special_skills)
      if self.player:canUse(self.selected_card) then
        table.insert(sp_skills, 1, "_normal_use")
      else
        self:selectSpecialUse(sp_skills[1])
      end
    end
    self.scene:update("SpecialSkills", "1", { skills = sp_skills })
  else
    self.selected_card = nil
    self:setPrompt(self.original_prompt)
    self.skill_name = nil
    self.scene:update("SpecialSkills", "1", { skills = {} })
  end
end

function ReqPlayCard:selectSkill(skill, data)
  ReqUseCard.selectSkill(self, skill, data)
  self.scene:update("SpecialSkills", "1", { skills = {} })
end

function ReqPlayCard:update(elemType, id, action, data)
  if elemType == "Button" then
    if id == "End" then
      self:doEndButton()
      return true
    end
    if id == "Cancel" then
      self:doCancelButton()
      return false
    end
  elseif elemType == "SpecialSkills" then
    self:selectSpecialUse(data)
  end
  return ReqUseCard.update(self, elemType, id, action, data)
end

return ReqPlayCard
