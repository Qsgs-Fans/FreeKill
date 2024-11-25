--- 用于对标room和room.logic的、专用于计算某一轮操作的收益的类。
---
--- 里面提供的方法和room尽可能完全一致，以便自动分析与手工编写简易预测流程。
---@class AIGameLogic: Object
---@field public ai SmartAI
---@field public player ServerPlayer
---@field public benefit integer
local AIGameLogic = class("AIGameLogic")

---@param ai SmartAI
function AIGameLogic:initialize(ai, base_benefit)
  self.benefit = base_benefit or 0
  self.ai = ai
  self.player = ai.player
  self.logic = self -- 用于处理room.logic 这样真的好么。。

  self.owner_map = ai.room.owner_map
  self.card_place = ai.room.card_place
end

function AIGameLogic:__index(_)
  return function() return Util.DummyTable end
end

function AIGameLogic:getPlayerById(id)
  return self.ai.room:getPlayerById(id)
end

function AIGameLogic:getOtherPlayers(p)
  return self.ai.room:getOtherPlayers(p)
end

function AIGameLogic:getSubcardsByRule(card, fromAreas)
  return Card:getIdList(card)
end

function AIGameLogic:trigger(event, target, data)
  local ai = self.ai
  local logic = ai.room.logic
  local skills = logic.skill_table[event] or Util.DummyTable
  local refresh_skills = logic.refresh_skill_table[event] or Util.DummyTable
  local _target = ai.room.current -- for iteration
  local player = _target
  local exit

  repeat
    for _, skill in ipairs(table.connectIfNeed(skills, refresh_skills)) do
      local skill_ai = fk.ai_trigger_skills[skill.name]
      if skill_ai then
        exit = skill_ai:getCorrect(self, event, target, player, data)
        if exit then break end
      end
    end
    if exit then break end
    player = player.next
  until player == _target

  return exit
end

--- 血条、翻面、铁索等等的收益论（瞎jb乱填版）
function AIGameLogic:setPlayerProperty(player, key, value)
  local orig = player[key]
  local benefit = 0
  if key == "hp" then
    benefit = (value - orig) * 200
  elseif key == "shield" then
    benefit = (value - orig) * 150
  elseif key == "chained" then
    benefit = value and -80 or 80
  elseif key == "faceup" then
    if value and not orig then
      benefit = 330
    elseif orig and not value then
      benefit = -330
    end
  end
  if self.ai:isEnemy(player) then benefit = -benefit end
  self.benefit = self.benefit + benefit
end

--- 牌差收益论（瞎jb乱填版）：
--- 根据moveInfo判断玩家是拿牌还是掉牌进而暴力算收益
---@param data CardsMoveStruct
---@param info MoveInfo
function AIGameLogic:applyMoveInfo(data, info)
  local benefit = 0

  if data.from then
    if info.fromArea == Player.Hand then
      benefit = -90
    elseif info.fromArea == Player.Equip then
      benefit = -110
    elseif info.fromArea == Player.Judge then
      benefit = 180
    elseif info.fromArea == Player.Special then
      benefit = -60
    end

    local from = data.from and self:getPlayerById(data.from)
    if from and self.ai:isEnemy(from) then benefit = -benefit end
    self.benefit = self.benefit + benefit
    benefit = 0
  end

  if data.to then
    if data.toArea == Player.Hand then
      benefit = 90
    elseif data.toArea == Player.Equip then
      benefit = 110
    elseif data.toArea == Player.Judge then
      benefit = -180
    elseif data.toArea == Player.Special then
      benefit = 60
    end

    local to = data.to and self:getPlayerById(data.to)
    if to and self.ai:isEnemy(to) then benefit = -benefit end
    self.benefit = self.benefit + benefit
  end
end

--- 阉割版GameEvent: 专用于AI进行简单的收益推理。
---
--- 事件首先需要定义自己对于某某玩家的基础收益值，例如伤害事件对目标造成-200的
--- 收益。事件还要定义自己包含的触发时机列表，根据时机列表考虑相关技能对本次
--- 事件的收益修正，最终获得真正的收益值。
---
--- 事件用于即将选卡/选目标时，或者触发技AI思考自己对某事件影响时构造并计算收益，
--- 因此很容易发生事件嵌套现象。为防止AI思考过久，必须对事件嵌套层数加以限制，
--- 比如限制最多思考到两层嵌套；毕竟没算力只能让AI蠢点了
---@class AIGameEvent: Object
---@field public ai SmartAI
---@field public logic AIGameLogic
---@field public player ServerPlayer
---@field public data any
local AIGameEvent = class("AIGameEvent")

---@param ai_logic AIGameLogic
function AIGameEvent:initialize(ai_logic, ...)
  self.room = ai_logic
  self.logic = ai_logic
  self.ai = ai_logic.ai
  self.player = self.ai.player
  self.data = { ... }
end

-- 真正的收益计算函数：子类重写这个
function AIGameEvent:exec()
end

local _depth = 0

-- 用做API的收益计算函数，不要重写
function AIGameEvent:getBenefit()
  local ret = true
  _depth = _depth + 1
  if _depth <= 30 then
    ret = self:exec()
  end
  _depth = _depth - 1
  return ret
end

-- hp.lua

local ChangeHp = AIGameEvent:subclass("AIGameEvent.ChangeHp")
fk.ai_events.ChangeHp = ChangeHp
function ChangeHp:exec()
  local logic = self.logic
  local player, num, reason, skillName, damageStruct = table.unpack(self.data)

  ---@type HpChangedData
  local data = {
    num = num,
    reason = reason,
    skillName = skillName,
    damageEvent = damageStruct,
  }

  if logic:trigger(fk.BeforeHpChanged, player, data) then
    return true
  end

  logic:setPlayerProperty(player, "hp", math.min(player.hp + data.num, player.maxHp))
  logic:trigger(fk.HpChanged, player, data)
end

function AIGameLogic:changeHp(player, num, reason, skillName, damageStruct)
  return not ChangeHp:new(self, player, num, reason, skillName, damageStruct):getBenefit()
end

local Damage = AIGameEvent:subclass("AIGameEvent.Damage")
fk.ai_events.Damage = Damage
function Damage:exec()
  local logic = self.logic
  local damageStruct = table.unpack(self.data)
  if (not damageStruct.chain) and (not damageStruct.chain_table) and Fk:canChain(damageStruct.damageType) then
    damageStruct.chain_table = table.filter(self.ai.room:getOtherPlayers(damageStruct.to), function(p)
      return p.chained
    end)
  end

  local stages = {}
  if not damageStruct.isVirtualDMG then
    stages = {
      { fk.PreDamage, "from"},
      { fk.DamageCaused, "from" },
      { fk.DamageInflicted, "to" },
    }
  end

  for _, struct in ipairs(stages) do
    local event, player = table.unpack(struct)
    if logic:trigger(event, damageStruct[player], damageStruct) then
      return true
    end
    if damageStruct.damage < 1 then return true end
  end

  if not damageStruct.isVirtualDMG then
    ChangeHp:new(logic, damageStruct.to, -damageStruct.damage,
      "damage", damageStruct.skillName, damageStruct):getBenefit()
  end

  logic:trigger(fk.Damage, damageStruct.from, damageStruct)
  logic:trigger(fk.Damaged, damageStruct.to, damageStruct)
  logic:trigger(fk.DamageFinished, damageStruct.to, damageStruct)

  if damageStruct.chain_table and #damageStruct.chain_table > 0 then
    for _, p in ipairs(damageStruct.chain_table) do
      local dmg = {
        from = damageStruct.from,
        to = p,
        damage = damageStruct.damage,
        damageType = damageStruct.damageType,
        card = damageStruct.card,
        skillName = damageStruct.skillName,
        chain = true,
      }

      Damage:new(logic, dmg):getBenefit()
    end
  end
end

function AIGameLogic:damage(damageStruct)
  return not Damage:new(self, damageStruct):getBenefit()
end

local LoseHp = AIGameEvent:subclass("AIGameEvent.LoseHp")
fk.ai_events.LoseHp = LoseHp
LoseHp.exec = AIParser.parseEventFunc(GameEvent.LoseHp.main)

function AIGameLogic:loseHp(player, num, skillName)
  return not LoseHp:new(self, player, num, skillName):getBenefit()
end

local Recover = AIGameEvent:subclass("AIGameEvent.Recover")
fk.ai_events.Recover = Recover
function Recover:exec()
  local recoverStruct = table.unpack(self.data) ---@type RecoverStruct
  local logic = self.logic

  local who = recoverStruct.who

  if logic:trigger(fk.PreHpRecover, who, recoverStruct) then
    return true
  end

  recoverStruct.num = math.min(recoverStruct.num, who.maxHp - who.hp)

  if recoverStruct.num < 1 then
    return true
  end

  if not logic:changeHp(who, recoverStruct.num, "recover", recoverStruct.skillName) then
    return true
  end

  logic:trigger(fk.HpRecover, who, recoverStruct)
end

function AIGameLogic:recover(recoverStruct)
  return not Recover:new(self, recoverStruct):getBenefit()
end

-- skill.lua

local SkillEffect = AIGameEvent:subclass("AIGameEvent.SkillEffect")
fk.ai_events.SkillEffect = SkillEffect
function SkillEffect:exec()
  local logic = self.logic
  local effect_cb, player, skill, skill_data = table.unpack(self.data)
  local main_skill = skill.main_skill and skill.main_skill or skill

  logic:trigger(fk.SkillEffect, player, main_skill)
  effect_cb()
  logic:trigger(fk.AfterSkillEffect, player, main_skill)
end

function AIGameLogic:useSkill(player, skill, effect_cb, skill_data)
  return not SkillEffect:new(self, effect_cb, player, skill, skill_data or Util.DummyTable):getBenefit()
end

-- movecard.lua
local MoveCards = AIGameEvent:subclass("AIGameEvent.MoveCards")
fk.ai_events.MoveCards = MoveCards
function MoveCards:exec()
  local args = self.data
  local logic = self.logic
  local cardsMoveStructs = {}

  for _, cardsMoveInfo in ipairs(args) do
    if #cardsMoveInfo.ids > 0 then
      ---@type MoveInfo[]
      local infos = {}
      for _, id in ipairs(cardsMoveInfo.ids) do
        table.insert(infos, {
          cardId = id,
          fromArea = cardsMoveInfo.fromArea or self.ai.room:getCardArea(id),
          fromSpecialName = cardsMoveInfo.from and logic:getPlayerById(cardsMoveInfo.from):getPileNameOfId(id),
        })
      end

      cardsMoveInfo.moveInfo = infos
      table.insert(cardsMoveStructs, cardsMoveInfo)
    end
  end

  if logic:trigger(fk.BeforeCardsMove, nil, cardsMoveStructs) then
    return true
  end

  for _, data in ipairs(cardsMoveStructs) do
    for _, info in ipairs(data.moveInfo) do
      logic:applyMoveInfo(data, info)
    end
  end

  logic:trigger(fk.AfterCardsMove, nil, cardsMoveStructs)
end

function AIGameLogic:getNCards(num, from)
  local cardIds = {}
  for _ = 1, num do
    table.insert(cardIds, 1)
  end
  return cardIds
end

function AIGameLogic:moveCards(...)
  return not MoveCards:new(self, ...):getBenefit()
end
AIGameLogic.moveCardTo = GameEventWrappers.moveCardTo
AIGameLogic.obtainCard = GameEventWrappers.obtainCard
AIGameLogic.drawCards = GameEventWrappers.drawCards
AIGameLogic.throwCard = GameEventWrappers.throwCard
function AIGameLogic:recastCard(card_ids, who, skillName)
  if type(card_ids) == "number" then
    card_ids = {card_ids}
  end
  skillName = skillName or "recast"
  self:moveCards({
    ids = card_ids,
    from = who.id,
    toArea = Card.DiscardPile,
    skillName = skillName,
    moveReason = fk.ReasonRecast,
    proposer = who.id
  })
  return self:drawCards(who, #card_ids, skillName)
end

-- usecard.lua

local UseCard = AIGameEvent:subclass("AIGameEvent.UseCard")
fk.ai_events.UseCard = UseCard
function UseCard:exec()
  local ai = self.ai
  local room = ai.room
  local logic = self.logic
  local cardUseEvent = table.unpack(self.data)

  if cardUseEvent.card.skill then
    local skill_ai = fk.ai_skills[cardUseEvent.card.skill.name]
    if skill_ai then skill_ai:onUse(logic, cardUseEvent) end
  end

  if logic:trigger(fk.PreCardUse, room:getPlayerById(cardUseEvent.from), cardUseEvent) then
    return true
  end
  logic:moveCardTo(cardUseEvent.card, Card.Processing, nil, fk.ReasonUse)

  for _, event in ipairs({ fk.AfterCardUseDeclared, fk.AfterCardTargetDeclared, fk.CardUsing }) do
    if not cardUseEvent.toCard and #TargetGroup:getRealTargets(cardUseEvent.tos) == 0 then
      break
    end

    logic:trigger(event, room:getPlayerById(cardUseEvent.from), cardUseEvent)
    if event == fk.CardUsing then
      logic:doCardUseEffect(cardUseEvent)
    end
  end

  logic:trigger(fk.CardUseFinished, room:getPlayerById(cardUseEvent.from), cardUseEvent)
  logic:moveCards{
    fromArea = Card.Processing,
    toArea = Card.DiscardPile,
    ids = Card:getIdList(cardUseEvent.card),
    moveReason = fk.ReasonUse,
  }
end

function AIGameLogic:useCard(cardUseEvent)
  return not UseCard:new(self, cardUseEvent):getBenefit()
end

function AIGameLogic:deadPlayerFilter(playerIds)
  local newPlayerIds = {}
  for _, playerId in ipairs(playerIds) do
    if self:getPlayerById(playerId):isAlive() then
      table.insert(newPlayerIds, playerId)
    end
  end

  return newPlayerIds
end

AIGameLogic.doCardUseEffect = GameEventWrappers.doCardUseEffect

local CardEffect = AIGameEvent:subclass("AIGameEvent.CardEffect")
fk.ai_events.CardEffect = CardEffect
CardEffect.exec = AIParser.parseEventFunc(GameEvent.CardEffect.main)

function AIGameLogic:doCardEffect(cardEffectEvent)
  return not CardEffect:new(self, cardEffectEvent):getBenefit()
end

function AIGameLogic:handleCardEffect(event, cardEffectEvent)
  -- 不考虑闪与无懈 100%生效
  -- 闪和无懈早该重构重构了
  if event == fk.CardEffecting then
    if cardEffectEvent.card.skill then
      SkillEffect:new(self, function()
        local skill = cardEffectEvent.card.skill
        local ai = fk.ai_skills[skill.name]
        if ai then
          ai:onEffect(self, cardEffectEvent)
        end
      end, self:getPlayerById(cardEffectEvent.from), cardEffectEvent.card.skill):getBenefit()
    end
  end
end

-- judge.lua

local Judge = AIGameEvent:subclass("AIGameEvent.Judge")
fk.ai_events.Judge = Judge
function Judge:exec()
  local data = table.unpack(self.data)
  local logic = self.logic
  local who = data.who

  data.isJudgeEvent = true
  logic:trigger(fk.StartJudge, who, data)
  data.card = data.card or Fk:getCardById(self.ai.room.draw_pile[1] or 1)

  logic:moveCardTo(data.card, Card.Processing, nil, fk.ReasonJudge)

  logic:trigger(fk.AskForRetrial, who, data)
  logic:trigger(fk.FinishRetrial, who, data)

  if logic:trigger(fk.FinishJudge, who, data) then
    return true
  end

  logic:moveCardTo(data.card, Card.DiscardPile, nil, fk.ReasonJudge)
end

---@param data JudgeStruct
function AIGameLogic:judge(data)
  return Judge:new(self, data):getBenefit()
end

-- 暂时不模拟改判。

return AIGameLogic, AIGameEvent
