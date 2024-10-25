local RoomScene = require 'ui_emu.roomscene'
local ReqActiveSkill = require 'core.request_type.active_skill'

--[[
  负责处理AskForResponseCard的Handler。
  涉及的UI组件：较基类增加技能按钮、减少角色
  可能发生的事件：
  * 点击手牌：取消选中其他牌
  * 按下按钮：发送答复
  * 点击技能按钮：若有则取消其他已按下按钮的按下，重置信息
  若有按下的技能按钮则走ActiveSkill合法性流程
--]]

---@class ReqResponseCard: ReqActiveSkill
---@field public selected_card? Card 使用一张牌时会用到 支持锁视技
---@field public pattern string 请求格式
---@field public original_prompt string 最开始的提示信息；这种涉及技能按钮的需要这样一下
local ReqResponseCard = ReqActiveSkill:subclass("ReqResponseCard")

function ReqResponseCard:setup()
  if not self.original_prompt then
    self.original_prompt = self.prompt or ""
  end

  ReqActiveSkill.setup(self)
  self.selected_card = nil
  self:updateSkillButtons()
end

-- FIXME: 关于&牌堆的可使用打出瞎jb写了点 来个懂哥优化一下
function ReqResponseCard:expandPiles()
  if self.skill_name then return ReqActiveSkill.expandPiles(self) end
  local player = self.player
  for pile in pairs(player.special_cards) do
    if pile:endsWith('&') then
      self:expandPile(pile)
    end
  end
end

function ReqResponseCard:skillButtonValidity(name)
  local player = self.player
  local skill = Fk.skills[name]
  return skill:isInstanceOf(ViewAsSkill) and skill:enabledAtResponse(player, true)
end

function ReqResponseCard:cardValidity(cid)
  if self.skill_name then return ReqActiveSkill.cardValidity(self, cid) end
  local card = cid
  if type(cid) == "number" then card = Fk:getCardById(cid) end
  return self:cardFeasible(card)
end

function ReqResponseCard:cardFeasible(card)
  local exp = Exppattern:Parse(self.pattern)
  local player = self.player
  return not player:prohibitResponse(card) and exp:match(card)
end

function ReqResponseCard:feasible()
  local skill = Fk.skills[self.skill_name]
  local card = self.selected_card
  if skill then
    card = skill:viewAs(self.pendings)
  end
  return card and self:cardFeasible(card)
end

function ReqResponseCard:isCancelable()
  if self.skill_name then return true end
  return self.cancelable
end

function ReqResponseCard:updateSkillButtons()
  local scene = self.scene
  for name, item in pairs(scene:getAllItems("SkillButton")) do
    local skill = Fk.skills[name]
    local ret = self:skillButtonValidity(name)
    if ret and skill:isInstanceOf(ViewAsSkill) then
      local exp = Exppattern:Parse(skill.pattern)
      local cnames = {}
      for _, m in ipairs(exp.matchers) do
        if m.name then table.insertTable(cnames, m.name) end
        if m.trueName then table.insertTable(cnames, m.trueName) end
      end
      for _, n in ipairs(cnames) do
        local c = Fk:cloneCard(n)
        c.skillName = name
        ret = self:cardValidity(c)
        if ret then break end
      end
    end
    scene:update("SkillButton", name, { enabled = not not ret })
  end
end

function ReqResponseCard:doOKButton()
  if self.skill_name then return ReqActiveSkill.doOKButton(self) end
  local reply = {
    card = self.selected_card:getEffectiveId(),
    targets = self.selected_targets,
  }
  ClientInstance:notifyUI("ReplyToServer", json.encode(reply))
end

function ReqResponseCard:doCancelButton()
  if self.skill_name then
    self:selectSkill(self.skill_name, { selected = false })
    self.scene:notifyUI()
    return
  end
  return ReqActiveSkill:doCancelButton()
end

function ReqResponseCard:selectSkill(skill, data)
  local scene = self.scene
  local selected = data.selected
  scene:update("SkillButton", skill, data)

  if selected then
    for name, item in pairs(scene:getAllItems("SkillButton")) do
      scene:update("SkillButton", name, { enabled = item.selected })
    end
    self.skill_name = skill
    self.selected_card = nil
    self:setSkillPrompt(skill)

    ReqActiveSkill.setup(self)
  else
    self.skill_name = nil
    self.prompt = self.original_prompt
    self:setup()
  end
end

function ReqResponseCard:selectCard(cid, data)
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
  else
    self.selected_card = nil
  end
end

function ReqResponseCard:update(elemType, id, action, data)
  if elemType == "CardItem" then
    self:selectCard(id, data)
    self:updateButtons()
  elseif elemType == "SkillButton" then
    self:selectSkill(id, data)
  else -- if elemType == "Button" or elemType == "Interaction" then
    return ReqActiveSkill.update(self, elemType, id, action, data)
  end
end

return ReqResponseCard
