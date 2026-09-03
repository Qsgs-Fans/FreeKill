local RoomScene = require 'ui_emu.roomscene'
local ReqActiveSkill = require 'ltk.core.request_type.active_skill'
local SpecialSkills = require 'ui_emu.specialskills'

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
---@field public selected_card? Card 选中的牌（锁视技转化后），用于使用真牌
---@field public pattern string 请求格式
local ReqResponseCard = ReqActiveSkill:subclass("ReqResponseCard")

function ReqResponseCard:initialize(player, data)
  ReqActiveSkill.initialize(self, player)

  if data then
    -- self.skill_name = data[1] (skill_name是给选中的视为技用的)
    self.pattern    = data[2]
    self.prompt     = data[3]
    self.cancelable = data[4]
    self.extra_data = data[5]
    self.disabledSkillNames = data[6]
  end
  self.scene:addItem(SpecialSkills:new(self.scene, "1"))
end

function ReqResponseCard:setup()
  if not self.original_prompt then
    self.original_prompt = self.prompt or ""
  end

  ReqActiveSkill.setup(self)
  self.selected_card = nil
  self:updateSkillButtons()
  self:updatePrompt()
end

function ReqResponseCard:expandPiles()
  if self.skill_name then return ReqActiveSkill.expandPiles(self) end
  local player = self.player
  local cardsExpanded = {}
  local filterSkills = Fk:currentRoom().status_skills[FilterSkill] or Util.DummyTable ---@type FilterSkill[]
  for _, filter in ipairs(filterSkills) do
    local ids = filter:handlyCardsFilter(player)
    if ids then
      ids = table.filter(ids, function(id) return not table.contains(cardsExpanded, id) end)
      if #ids > 0 then
        self:expandPile(filter.name, ids)
        table.insertTable(cardsExpanded, ids)
      end
    end
  end
end

function ReqResponseCard:skillButtonValidity(name)
  if self.sub_selection_flag then return false end -- 处于二级选择时不允许切换技能
  local player = self.player
  local skill = Fk.skills[name] ---@cast skill ViewAsSkill
  return
    skill:isInstanceOf(ViewAsSkill) and
    skill:enabledAtResponse(player, true) and
    skill.pattern and
    Exppattern:Parse(self.pattern):matchExp(skill.pattern) and
    not table.contains(self.disabledSkillNames or {}, name)
end

--- 获得此时所返回的牌
---@return Card|nil
function ReqResponseCard:getUsingCard()
  if self.selected_card then
    local skill = Fk.skills[self.skill_name] ---@cast skill ViewAsSkill
    if skill and skill:isInstanceOf(ViewAsSkill) then
      return skill:viewAs(self.player, { self.selected_card.id })
    else
      return self.selected_card
    end
  else
    return ReqActiveSkill.getUsingCard(self)
  end
end

--- 一张牌能否被点亮（包括正在被点选的实体牌）
---@param cid integer|Card
---@return boolean
function ReqResponseCard:cardValidity(cid)
  if self.skill_name then return ReqActiveSkill.cardValidity(self, cid) end
  local card = cid
  if type(cid) == "number" then card = Fk:getCardById(cid) end
  return not not self:cardFeasible(card)
end

function ReqResponseCard:targetValidity(pid)
  local skill = Fk.skills[self.skill_name] ---@cast skill ViewAsSkill
  local card = self:getUsingCard()
  if skill and card == nil then
    local sub_data = type(skill.sub_data) == "function" and skill:sub_data(self.player, self.pendings) or skill.sub_data
    if sub_data then
      return false -- 需要二级选择的技能，暂时不考虑targetFilter
    end
    local p = Fk:currentRoom():getPlayerById(pid)
    local selected = table.map(self.selected_targets, Util.Id2PlayerMapper)
    return not not skill:targetFilter(self.player, p, selected, self.pendings, nil, self.extra_data)
  end
  return false
end

function ReqResponseCard:cardFeasible(card)
  local exp = Exppattern:Parse(self.pattern)
  local player = self.player
  if not player:prohibitResponse(card) and exp:match(card) then
    return true
  else
    local skills = card.special_skills
    if not skills then return false end
    for _, skill in ipairs(skills) do
      local s = Fk.skills[skill]  ---@cast s ViewAsSkill
      if s:isInstanceOf(ViewAsSkill) and s:enabledAtResponse(player, true) then
        return true
      end
    end
  end
end

function ReqResponseCard:feasible()
  local skill = Fk.skills[self.skill_name]---@cast skill ViewAsSkill
  local card = self:getUsingCard()
  if skill and card == nil and not self.sub_selection_flag then
    local selected = table.map(self.selected_targets, Util.Id2PlayerMapper)
    return skill:feasible(self.player, selected, self.pendings)
  end
  return (card ~= nil) and self:cardFeasible(card)
end

function ReqResponseCard:isCancelable()
  if self.skill_name then return true end
  return not not self.cancelable
end

--- 选择一个卡牌特殊技能（如重铸）
---@param data string? @ 特殊技能名，不填为正常使用
function ReqResponseCard:selectSpecialUse(data)
  -- 相当于使用一个以已选牌为pendings的主动技
  if not data or data == "_normal_use" then
    self.skill_name = nil
    self.pendings = nil
  else
    self.skill_name = data
    self.pendings = Card:getIdList(self.selected_card)
  end
  self:initiateTargets()
end

function ReqResponseCard:updateSkillButtons()
  local scene = self.scene
  for name, item in pairs(scene:getAllItems("SkillButton")) do
    local ret = self:skillButtonValidity(name) -- 分散判断
    scene:update("SkillButton", name, { enabled = not not ret })
  end
end

---@class ReplyFormatResponseCard: ReplyFormatActive
---@field public card { skill: string, subcards: integer[] }|integer @ 选中的牌信息

function ReqResponseCard:doOKButton()
  self.scene:update("SpecialSkills", "1", { skills = {} })
  self.scene:notifyUI()
  if self.skill_name then
    return ReqActiveSkill.doOKButton(self)
  end
  local reply = {
    card = self.selected_card:getEffectiveId(), -- FIXME: 以小错防大错
    targets = self.selected_targets or {},
    special_skill = self.skill_name,
  }
  if ClientInstance then
    ClientInstance:notifyUI("ReplyToServer", reply)
  else
    return reply
  end
end

function ReqResponseCard:doCancelButton()
  self.scene:update("SpecialSkills", "1", { skills = {} })
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
  scene:update("SpecialSkills", "1", { skills = {} })

  if data.selected == false then
    self.sub_selection_flag = false -- 提前重置二级选择状态
  end

  if selected then
    ---@param item SelectableItem
    for name, item in pairs(scene:getAllItems("SkillButton")) do
      scene:update("SkillButton", name, { enabled = item.selected })
    end
    self.skill_name = skill
    self.selected_card = nil

    ReqActiveSkill.setup(self, false, data)

    -- self:setSkillPrompt(Fk.skills[skill])
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
    local sp_skills = {}
    if self.selected_card.special_skills then
      for _, s in ipairs(self.selected_card.special_skills or {}) do
        local skill = Fk.skills[s]
        if skill:isInstanceOf(ViewAsSkill) and table.contains(self.player:getHandlyIds(), cid) then
          skill = skill  ---@cast skill ViewAsSkill
          if skill:enabledAtResponse(self.player, true) then
            table.insert(sp_skills, s)
          end
        end
      end
      if #sp_skills > 0 then
        self:selectSpecialUse(sp_skills[1])
      end
    end
    self.scene:update("SpecialSkills", "1", { skills = sp_skills })
  else
    self.selected_card = nil
    self.skill_name = nil
    self.scene:update("SpecialSkills", "1", { skills = {} })
  end
end

--- 自动选择唯一目标
---@param req ReqResponseCard
local function autoSelectOnlyFeasibleTarget(req, data)
  if data.autoTarget and not req:feasible() then
    local tars = {}
    for _, to in ipairs(req.room.alive_players) do
      if req:targetValidity(to.id) then
        table.insert(tars, to.id)
        if #tars > 1 then return end
      end
    end
    if #tars == 1 then
      req.selected_targets = tars
      req.scene:update("Photo", tars[1], { selected = true })
      req:updateUnselectedTargets()
      req:updateButtons()
    end
  end
end

function ReqResponseCard:update(elemType, id, action, data)
  if elemType == "SkillButton" then
    self:selectSkill(id, data)
    -- 自动选择唯一目标
    autoSelectOnlyFeasibleTarget(self, data)
    -- 双击发动技能
    --[[
    if data.doubleClickUse and action == "doubleClick" then
      if not data.selected then -- 未选中的选中
        self:selectSkill(id, data)
        self:initiateTargets()
        autoSelectOnlyFeasibleTarget(self, data)
      end
      if self:feasible() then
        self:doOKButton()
      else
        data.selected = false
        self:selectSkill(id, data)
        self:initiateTargets()
      end
    end
    ]]
  else -- if elemType == "Button" or elemType == "Interaction" or elemType == "CardItem" then
    return ReqActiveSkill.update(self, elemType, id, action, data)
  end
end

return ReqResponseCard
