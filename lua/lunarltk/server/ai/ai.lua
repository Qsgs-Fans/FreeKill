-- SPDX-License-Identifier: GPL-3.0-or-later

-- AI base class.
-- Do nothing.

---@class AI: Base.AI
---@field public room Room
---@field public player ServerPlayer
---@field public handler ReqActiveSkill
local AI = Fk.Base.AI:subclass("AI")

-- activeSkill, responseCard, useCard, playCard 四巨头专属
function AI:isInDashboard()
  if not (self.handler and self.handler:isInstanceOf(self.room.request_handlers["AskForUseActiveSkill"])) then
    fk.qWarning("请检查是否在AI中调用了专属于dashboard操作的一系列函数")
    fk.qWarning(debug.traceback())
    return false
  end
  return true
end

function AI:getPrompt()
  local handler = self.handler
  if not handler then return "" end
  return handler.prompt
end

--- 返回当前手牌区域内（包含展开的pile）中所有可选且未选中的卡牌 返回ids
---@param pattern string? 可以带一个过滤条件
---@return integer[]
function AI:getEnabledCards(pattern)
  if not self:isInDashboard() then return Util.DummyTable end

  local ret = {}
  for cid, item in pairs(self.handler.scene:getAllItems("CardItem")) do
    if item.enabled and not item.selected then
      if (not pattern) or Exppattern:Parse(pattern):match(Fk:getCardById(cid)) then
        table.insert(ret, cid)
      end
    end
  end
  return ret
end

--- 返回当前所有可选并且还未选中的角色，包括自己
---@return ServerPlayer[]
function AI:getEnabledTargets()
  if not self:isInDashboard() then return Util.DummyTable end
  local room = self.room

  local ret = {}
  for pid, item in pairs(self.handler.scene:getAllItems("Photo")) do
    if item.enabled and not item.selected then
      table.insert(ret, room:getPlayerById(pid))
    end
  end
  return ret
end

function AI:hasEnabledTarget()
  if not self:isInDashboard() then return false end
  local room = self.room

  for _, item in pairs(self.handler.scene:getAllItems("Photo")) do
    if item.enabled and not item.selected then
      return true
    end
  end
  return false
end

--- 获取技能面板中所有可以按下的技能按钮
---@return string[]

--- 获取技能面板中所有可以按下的技能按钮
---@return string[]
function AI:getEnabledSkills()
  if not self:isInDashboard() then return Util.DummyTable end

  local ret = {}
  for name, item in pairs(self.handler.scene:getAllItems("SkillButton")) do
    if item.enabled and not item.selected then
      table.insert(ret, name)
    end
  end
  return ret
end

---@return integer[]
function AI:getSelectedCards()
  if not self:isInDashboard() then return Util.DummyTable end
  return table.simpleClone(self.handler.pendings)
end

---@return Card?
function AI:getSelectedCard()
  if not self:isInDashboard() then return Util.DummyTable end
  local handler = self.handler
  if handler.selected_card then return handler.selected_card end
  if not handler.skill_name then return end
  local skill = Fk.skills[handler.skill_name]
  if not skill:isInstanceOf(ViewAsSkill) then return end
  return skill:viewAs(self.player, handler.pendings)
end

---@return ServerPlayer[]
function AI:getSelectedTargets()
  if not self:isInDashboard() then return Util.DummyTable end
  return table.map(self.handler.selected_targets, function(pid)
    return self.room:getPlayerById(pid)
  end)
end

function AI:getSelectedSkill()
  if not self:isInDashboard() then return nil end
  return self.handler.skill_name
end

function AI:selectCard(cid, selected)
  if not self:isInDashboard() then return end
  verbose(0,"%s选择卡牌%d(%s)", selected and "" or "取消", cid, tostring(Fk:getCardById(cid)))
  self.handler:update("CardItem", cid, "click", { selected = selected })
end

---@param player ServerPlayer
function AI:selectTarget(player, selected)
  if not self:isInDashboard() then return end
  verbose(0,"%s选择角色%s", selected and "" or "取消", tostring(player))
  self.handler:update("Photo", player.id, "click", { selected = selected })
end

function AI:selectSkill(skill_name, selected)
  if not self:isInDashboard() then return end
  local items = self.handler.scene.items
  if not items["SkillButton"] then return end
  if not items["SkillButton"][skill_name] then return end
  verbose(0,"%s选择技能%s", selected and "" or "取消", skill_name)
  self.handler:update("SkillButton", skill_name, "click", { selected = selected })
end

function AI:unSelectAllCards()
  for _, id in ipairs(self:getSelectedCards()) do
    self:selectCard(id, false)
  end
end

function AI:unSelectAllTargets()
  for _, p in ipairs(self:getSelectedTargets()) do
    self:selectTarget(p, false)
  end
end

function AI:unSelectSkill()
  local skill = self:getSelectedSkill()
  if not skill then return end
  self:selectSkill(skill, false)
end

function AI:unSelectAll()
  self:unSelectSkill()
  self:unSelectAllCards()
  self:unSelectAllTargets()
end

function AI:okButtonEnabled()
  if not self:isInDashboard() then return false end
  return self.handler:feasible()
end

function AI:isDeadend()
  if not self:isInDashboard() then return true end
  return (not self:okButtonEnabled()) and #self:getEnabledCards() == 0
    and #self:getEnabledTargets() == 0
end

function AI:doOKButton()
  if not self:isInDashboard() then return end
  if not self:okButtonEnabled() then return "" end
  return self.handler:doOKButton()
end

---@return Skill?
function AI:currentSkill()
  local room = self.room
  if room.current_cost_skill then return room.current_cost_skill end
  local sname = room.logic:getCurrentSkillName()
  if sname then
    return Fk.skills[sname]
  end
end

function AI:makeReply()
  local is_active = self.command == "AskForUseActiveSkill"
  if is_active then
    local skill = Fk.skills[self.data[1]]
    skill._extra_data = self.data[4]
  end

  local ret = Fk.Base.AI.makeReply(self)

  if is_active then
    local skill = Fk.skills[self.data[1]]
    skill._extra_data = Util.DummyTable
  end

  return ret
end

return AI
