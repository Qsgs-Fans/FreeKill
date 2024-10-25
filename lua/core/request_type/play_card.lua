local ReqActiveSkill = require 'core.request_type.active_skill'
local ReqUseCard = require 'lua.core.request_type.use_card'
local SpecialSkills = require 'ui_emu.specialskills'
local Button = (require 'ui_emu.control').Button

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

  self:setPrompt(self.original_prompt)
  self.scene:update("Button", "End", { enabled = true })
end

function ReqPlayCard:cardValidity(cid)
  if self.skill_name and not self.selected_card then return ReqActiveSkill.cardValidity(self, cid) end
  local player = self.player
  local card = cid
  if type(cid) == "number" then card = Fk:getCardById(cid) end
  local ret = player:canUse(card)
  if ret then
    local min_target = card.skill:getMinTargetNum()
    if min_target > 0 then
      for pid, _ in pairs(self.scene:getAllItems("Photo")) do
        if card.skill:targetFilter(pid, {}, {}, card, self.extra_data) then
          return true
        end
      end
      return false
    end
  end
  return ret
end

function ReqPlayCard:skillButtonValidity(name)
  local player = self.player
  local skill = Fk.skills[name]
  if skill:isInstanceOf(ViewAsSkill) then
    return skill:enabledAtPlay(player, true)
  elseif skill:isInstanceOf(ActiveSkill) then
    return skill:canUse(player, nil)
  end
end

function ReqPlayCard:feasible()
  local player = self.player
  if self.skill_name then
    return ReqActiveSkill.feasible(self)
  end
  local card = self.selected_card
  local ret = false
  if card then
    local skill = card.skill ---@type ActiveSkill
    ret = skill:feasible(self.selected_targets, { card.id }, player, card)
  end
  return ret
end

function ReqPlayCard:selectSpecialUse(data)
  -- 相当于使用一个以已选牌为pendings的主动技
  if not data or data == "_normal_use" then
    self.skill_name = nil
    self.pendings = nil
    self:setSkillPrompt(self.selected_card.skill, self.selected_card:getEffectiveId())
  else
    self.skill_name = data
    self.pendings = Card:getIdList(self.selected_card)
    self:setSkillPrompt(Fk.skills[data], self.pendings)
  end
  self:initiateTargets()
end

function ReqPlayCard:doOKButton()
  self.scene:update("SpecialSkills", "1", { skills = {} })
  self.scene:notifyUI()
  return ReqUseCard.doOKButton(self)
end

function ReqPlayCard:doCancelButton()
  self.scene:update("SpecialSkills", "1", { skills = {} })
  self.scene:notifyUI()
  return ReqUseCard.doCancelButton(self)
end

function ReqPlayCard:doEndButton()
  self.scene:update("SpecialSkills", "1", { skills = {} })
  self.scene:notifyUI()
  ClientInstance:notifyUI("ReplyToServer", "")
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
    self:setSkillPrompt(self.selected_card.skill, self.selected_card:getEffectiveId())
    local sp_skills = {}
    if self.selected_card.special_skills then
      sp_skills = table.simpleClone(self.selected_card.special_skills)
      if self:cardValidity(self.selected_card) then
        table.insert(sp_skills, 1, "_normal_use")
      end
    end
    self.scene:update("SpecialSkills", "1", { skills = sp_skills })
  else
    self.selected_card = nil
    self:setPrompt(self.original_prompt)
    self.scene:update("SpecialSkills", "1", { skills = {} })
  end
end

function ReqPlayCard:selectSkill(skill, data)
  ReqUseCard.selectSkill(self, skill, data)
  self.scene:update("SpecialSkills", "1", { skills = {} })
end

function ReqPlayCard:update(elemType, id, action, data)
  if elemType == "Button" and id == "End" then
    self:doEndButton()
    return true
  elseif elemType == "SpecialSkills" then
    self:selectSpecialUse(data)
  end
  return ReqUseCard.update(self, elemType, id, action, data)
end

return ReqPlayCard
