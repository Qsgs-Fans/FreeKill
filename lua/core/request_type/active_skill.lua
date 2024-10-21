local RoomScene = require 'ui_emu.roomscene'
local Interaction = require 'ui_emu.interaction'
local CardItem = (require 'ui_emu.common').CardItem

--[[
  负责处理AskForUseActiveSkill的Handler。
  涉及的UI组件：手牌区内的牌（TODO：expand牌）、在场角色、确定取消按钮
                （TODO：interaction小组件）
  可能发生的事件：
  * 点击手牌：刷新所有未选中牌的enable
  * 点击角色：刷新所有未选中的角色
  * (TODO) 修改interaction：重置信息
  * 按下按钮：发送答复

  为了后续的复用性需将ViewAsSkill也考虑进去
--]]

---@class ReqActiveSkill: RequestHandler
---@field public skill_name string 当前响应的技能名
---@field public prompt string 提示信息
---@field public cancelable boolean 可否取消
---@field public extra_data UseExtraData 传入的额外信息
---@field public pendings integer[] 卡牌id数组
---@field public selected_targets integer[] 选择的目标
---@field public expanded_piles { [string]: integer[] } 用于展开/收起
local ReqActiveSkill = RequestHandler:subclass("ReqActiveSkill")

function ReqActiveSkill:initialize(player)
  RequestHandler.initialize(self, player)
  self.scene = RoomScene:new(self)

  self.expanded_piles = {}
end

function ReqActiveSkill:setup(ignoreInteraction)
  local scene = self.scene

  -- FIXME: 偷懒了，让修改interaction时的全局刷新功能复用setup 总之这里写的很垃圾
  if not ignoreInteraction then
    scene:removeItem("Interaction", "1")
    self:setupInteraction()
  end

  self:setPrompt(self.prompt)

  self.pendings = {}
  self:retractAllPiles()
  self:expandPiles()
  scene:unselectAllCards()

  self.selected_targets = {}
  scene:unselectAllTargets()

  self:updateUnselectedCards()
  self:updateUnselectedTargets()

  self:updateButtons()
end

function ReqActiveSkill:finish()
  self:retractAllPiles()
end

function ReqActiveSkill:setSkillPrompt(skill, cid)
  local prompt = skill.prompt
  if type(skill.prompt) == "function" then
    prompt = skill:prompt(cid or self.pendings, self.selected_targets)
  end
  if type(prompt) == "string" then
    self:setPrompt(prompt)
  else
    self:setPrompt(self.original_prompt or "")
  end
end

function ReqActiveSkill:setupInteraction()
  local skill = Fk.skills[self.skill_name]
  if skill and skill.interaction then
    skill.interaction.data = nil -- FIXME
    local interaction = skill:interaction()
    -- 假设只有1个interaction （其实目前就是这样）
    local i = Interaction:new(self.scene, "1", interaction)
    i.skill_name = self.skill_name
    self.scene:addItem(i)
  end
end

function ReqActiveSkill:expandPile(pile, extra_ids, extra_footnote)
  if self.expanded_piles[pile] ~= nil then return end
  local ids, footnote
  local player = self.player

  if pile == "_equip" then
    ids = player:getCardIds("e")
    footnote = "$Equip"
  elseif pile == "_extra" then
    ids = extra_ids
    footnote = extra_footnote
    -- self.extra_cards = exira_ids
  else
    -- FIXME: 可能存在的浅拷贝
    ids = table.simpleClone(player:getPile(pile))
    footnote = pile
  end
  self.expanded_piles[pile] = ids

  local scene = self.scene
  for _, id in ipairs(ids) do
    scene:addItem(CardItem:new(scene, id), {
      reason = "expand",
      footnote = footnote,
    })
  end
end

function ReqActiveSkill:retractPile(pile)
  if self.expanded_piles[pile] == nil then return end
  local ids = self.expanded_piles[pile]
  self.expanded_piles[pile] = nil

  local scene = self.scene
  for _, id in ipairs(ids) do
    scene:removeItem("CardItem", id, { reason = "retract" })
  end
end

function ReqActiveSkill:retractAllPiles()
  for k, v in pairs(self.expanded_piles) do
    self:retractPile(k)
  end
end

function ReqActiveSkill:expandPiles()
  local skill = Fk.skills[self.skill_name]
  local player = self.player
  if not skill then return end
  -- 特殊：equips至少有一张能亮着的情况下才展开 且无视是否存在skill.expand_pile
  for _, id in ipairs(player:getCardIds("e")) do
    if self:cardValidity(id) then
      self:expandPile("_equip")
      break
    end
  end

  if not skill.expand_pile then return end
  local pile = skill.expand_pile
  if type(pile) == "function" then
    pile = pile(skill)
  end

  local ids = pile
  if type(pile) == "string" then
    ids = player:getPile(pile)
  else -- if type(pile) == "table" then
    pile = "_extra"
  end

  self:expandPile(pile, ids, self.skill_name)
end

function ReqActiveSkill:feasible()
  local player = self.player
  local skill = Fk.skills[self.skill_name]
  if not skill then return false end
  local ret
  if skill:isInstanceOf(ActiveSkill) then
    ret = skill:feasible(self.selected_targets, self.pendings, player)
  elseif skill:isInstanceOf(ViewAsSkill) then
    local card = skill:viewAs(self.pendings)
    if card then
      local card_skill = card.skill ---@type ActiveSkill
      ret = card_skill:feasible(self.selected_targets, { card.id }, player, card)
    end
  end
  return ret
end

function ReqActiveSkill:isCancelable()
  return self.cancelable
end

function ReqActiveSkill:cardValidity(cid)
  local skill = Fk.skills[self.skill_name]
  if not skill then return false end
  return skill:cardFilter(cid, self.pendings)
end

function ReqActiveSkill:extraDataValidity(pid)
  local data = self.extra_data or {}
  -- 逻辑块地狱
  if data.must_targets then
    -- must_targets: 必须先选择must_targets内的**所有**目标
    if not (#data.must_targets <= #self.selected_targets or
      table.contains(data.must_targets, pid)) then return false end
  end
  if data.include_targets then
    -- include_targets: 必须先选择include_targets内的**其中一个**目标
    if not (table.hasIntersection(data.include_targets, self.selected_targets) or
      table.contains(data.include_targets, pid)) then return false end
  end
  if data.exclusive_targets then
    -- exclusive_targets: **只能选择**exclusive_targets内的目标
    if not table.contains(data.exclusive_targets, pid) then return false end
  end
  return true
end

function ReqActiveSkill:targetValidity(pid)
  if not self:extraDataValidity(pid) then return false end

  local skill = Fk.skills[self.skill_name] --- @type ActiveSkill | ViewAsSkill
  if not skill then return false end
  local card -- 姑且接一下(雾)
  if skill:isInstanceOf(ViewAsSkill) then
    card = skill:viewAs(self.pendings)
    if not card or self.player:isProhibited(self.room:getPlayerById(pid), card) then return false end
    skill = card.skill
  end
  return skill:targetFilter(pid, self.selected_targets, self.pendings, card, self.extra_data)
end

function ReqActiveSkill:updateButtons()
  local scene = self.scene
  scene:update("Button", "OK", { enabled = not not self:feasible() })
  scene:update("Button", "Cancel", { enabled = not not self:isCancelable() })
end

function ReqActiveSkill:updateUnselectedCards()
  local scene = self.scene

  for cid, item in pairs(scene:getAllItems("CardItem")) do
    if not item.selected then
      scene:update("CardItem", cid, { enabled = not not self:cardValidity(cid) })
    end
  end
end

function ReqActiveSkill:updateUnselectedTargets()
  local scene = self.scene

  for pid, item in pairs(scene:getAllItems("Photo")) do
    if not item.selected then
      scene:updateTargetEnability(pid, self:targetValidity(pid))
    end
  end
end

function ReqActiveSkill:initiateTargets()
  local room = self.room
  local scene = self.scene
  local skill = Fk.skills[self.skill_name]
  if skill:isInstanceOf(ViewAsSkill) then
    local card = skill:viewAs(self.pendings)
    if card then skill = card.skill else skill = nil end
  end

  self.selected_targets = {}
  scene:unselectAllTargets()
  if skill then
    self:updateUnselectedTargets()
  else
    scene:disableAllTargets()
  end
  self:updateButtons()
end

function ReqActiveSkill:updateInteraction(data)
  local skill = Fk.skills[self.skill_name]
  if skill and skill.interaction then
    skill.interaction.data = data
    self.scene:update("Interaction", "1", { data = data })
    ReqActiveSkill.setup(self, true) -- interaction变动后需复原
  end
end

function ReqActiveSkill:doOKButton()
  local skill = Fk.skills[self.skill_name]
  local cardstr = json.encode{
    skill = self.skill_name,
    subcards = self.pendings
  }
  local reply = {
    card = cardstr,
    targets = self.selected_targets,
    --special_skill = roomScene.getCurrentCardUseMethod(),
    interaction_data = skill and skill.interaction and skill.interaction.data,
  }
  if self.selected_card then
    reply.special_skill = self.skill_name
  end
  ClientInstance:notifyUI("ReplyToServer", json.encode(reply))
end

function ReqActiveSkill:doCancelButton()
  ClientInstance:notifyUI("ReplyToServer", "__cancel")
end

-- 对点击卡牌的处理。data中包含selected属性，可能是选中或者取消选中，分开考虑。
function ReqActiveSkill:selectCard(cardid, data)
  local scene = self.scene
  local selected = data.selected
  scene:update("CardItem", cardid, data)

  -- 若选中，则加入已选列表；若取消选中，则其他牌可能无法满足可选条件，需额外判断
  -- 例如周善 选择包括“安”在内的任意张手牌交出
  if selected then
    table.insert(self.pendings, cardid)
  else
    local old_pendings = table.simpleClone(self.pendings)
    self.pendings = {}
    for _, cid in ipairs(old_pendings) do
      local ret = cid ~= cardid and self:cardValidity(cid)
      if ret then table.insert(self.pendings, cid) end
      -- 因为这里而变成未选中的牌稍后将更新一次enable 但是存在着冗余的cardFilter调用
      scene:update("CardItem", cid, { selected = not not ret })
    end
  end

  -- 最后刷新未选牌的enable属性
  self:updateUnselectedCards()
end

-- 对点击角色的处理。data中包含selected属性，可能是选中或者取消选中。
function ReqActiveSkill:selectTarget(playerid, data)
  local scene = self.scene
  local selected = data.selected
  local skill = Fk.skills[self.skill_name]
  scene:update("Photo", playerid, data)
  -- 发生以下Viewas判断时已经是因为选角色触发的了，说明肯定有card了，这么写不会出事吧？
  if skill:isInstanceOf(ViewAsSkill) then
    skill = skill:viewAs(self.pendings).skill
  end

  -- 类似选卡
  if selected then
    table.insert(self.selected_targets, playerid)
  else
    local old_targets = table.simpleClone(self.selected_targets)
    self.selected_targets = {}
    scene:unselectAllTargets()
    for _, pid in ipairs(old_targets) do
      local ret = pid ~= playerid and self:targetValidity(pid)
      if ret then table.insert(self.selected_targets, pid) end
      scene:update("Photo", pid, { selected = not not ret })
    end
  end

  self:updateUnselectedTargets()
  self:updateButtons()
end

function ReqActiveSkill:update(elemType, id, action, data)
  if elemType == "Button" then
    if id == "OK" then self:doOKButton()
    elseif id == "Cancel" then self:doCancelButton() end
    return true
  elseif elemType == "CardItem" then
    self:selectCard(id, data)
    self:initiateTargets()
  elseif elemType == "Photo" then
    self:selectTarget(id, data)
  elseif elemType == "Interaction" then
    self:updateInteraction(data)
  end
end

return ReqActiveSkill
