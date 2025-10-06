--- 用于对标room和room.logic的、专用于计算某一轮操作的收益的类。
---
--- 里面提供的方法和room尽可能完全一致，以便自动分析与手工编写简易预测流程。
---@class AIGameLogic: Object
---@field public ai SmartAI
---@field public player ServerPlayer
---@field public benefit integer
local AIGameLogic = class("AIGameLogic")

local GameEventWrappers = require "lunarltk.server.events"

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

function AIGameLogic:getCardOwner(id)
  return self.ai.room:getCardOwner(id)
end

---@param event TriggerEvent
---@param target? ServerPlayer
---@param data? any
---@return boolean?
function AIGameLogic:trigger(event, target, data)
  local ai = self.ai
  local logic = ai.room.logic
  local skills = logic.skill_table[event] or {}
  local _target = ai.room.current -- for iteration
  local player = _target
  local exit

  repeat
    for _, skill in ipairs(skills) do
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

--- 牌差收益论：根据moveInfo判断收益
---@param data MoveCardsData
---@param info MoveInfo
function AIGameLogic:applyMoveInfo(data, info)
  local benefit = 0
  local card_value = fk.ai_card_keep_value[Fk:getCardById(info.cardId).name] or 100

  if data.from then
    if info.fromArea == Player.Hand then
      benefit = -(card_value - 10)
    elseif info.fromArea == Player.Equip then
      benefit = -(card_value + 10)
    elseif info.fromArea == Player.Judge then
      benefit = card_value
    elseif info.fromArea == Player.Special then
      benefit = -(card_value / 2)
    end

    local from = data.from
    if from and self.ai:isEnemy(from) then benefit = -benefit end
    if data.moveReason == fk.ReasonUse then
      -- benefit = benefit / 10
      -- 当没写卡牌生效的ai时，随机出牌
      benefit = -0.5 - math.random()
    end
    self.benefit = self.benefit + benefit
    benefit = 0
  end

  if data.to then
    if data.toArea == Player.Hand then
      benefit = card_value - 10
    elseif data.toArea == Player.Equip then
      benefit = card_value + 10
    elseif data.toArea == Player.Judge then
      benefit = -card_value
    elseif data.toArea == Player.Special then
      benefit = card_value / 2
    end

    local to = data.to
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
  if #self.data == 1 then self.data = self.data[1] end
end

-- 真正的收益计算函数：子类重写这个
function AIGameEvent:exec()
end

local _depth = 0

-- 用做API的收益计算函数，不要重写
function AIGameEvent:getBenefit()
  local ret = true
  _depth = _depth + 1
  if _depth <= 20 then
    ret = self:exec()
  end
  _depth = _depth - 1
  return ret
end

-- hp.lua
---@class AIGameEvent.ChangeHp : AIGameEvent
---@field public data HpChangedData
local ChangeHp = AIGameEvent:subclass("AIGameEvent.ChangeHp")
fk.ai_events.ChangeHp = ChangeHp
function ChangeHp:exec()
  local logic = self.logic
  local data = self.data
  local player = data.who

  logic:trigger(fk.BeforeHpChanged, player, data)
  if data.num == 0 and data.shield_lost == 0 then
    data.prevented = true
  end
  if data.prevented then
    return true
  end

  logic:setPlayerProperty(player, "hp", math.min(player.hp + data.num, player.maxHp))
  logic:trigger(fk.HpChanged, player, data)
end

function AIGameLogic:changeHp(player, num, reason, skillName, damageData)
  local data = HpChangedData:new{
    who = player,
    num = num,
    reason = reason,
    skillName = skillName,
    damageEvent = damageData
  }
  return not ChangeHp:new(self, data):getBenefit()
end

local Damage = AIGameEvent:subclass("AIGameEvent.Damage")
fk.ai_events.Damage = Damage
function Damage:exec()
  local logic = self.logic
  local damageData = self.data
  if (not damageData.chain) and (not damageData.chain_table) and Fk:canChain(damageData.damageType) then
    damageData.chain_table = table.filter(self.ai.room:getOtherPlayers(damageData.to), function(p)
      return p.chained
    end)
  end

  local stages = {}
  if not damageData.isVirtualDMG then
    stages = {
      { fk.PreDamage, "from"},
      { fk.DamageCaused, "from" },
      { fk.DetermineDamageCaused, "from" },
      { fk.DamageInflicted, "to" },
      { fk.DetermineDamageInflicted, "to" },
    }
  end

  for _, struct in ipairs(stages) do
    local event, player = table.unpack(struct)
    logic:trigger(event, damageData[player], damageData)
    if damageData.prevented or damageData.damage < 1 then
      return true
    end
  end

  if not damageData.isVirtualDMG then
    logic:changeHp(damageData.to, -damageData.damage,
      "damage", damageData.skillName, damageData)
  end

  logic:trigger(fk.Damage, damageData.from, damageData)
  logic:trigger(fk.Damaged, damageData.to, damageData)
  logic:trigger(fk.DamageFinished, damageData.to, damageData)

  if damageData.chain_table and #damageData.chain_table > 0 then
    for _, p in ipairs(damageData.chain_table) do
      local dmg = DamageData:new{
        from = damageData.from,
        to = p,
        damage = damageData.damage,
        damageType = damageData.damageType,
        card = damageData.card,
        skillName = damageData.skillName,
        chain = true,
      }

      Damage:new(logic, dmg):getBenefit()
    end
  end
end

---@param damageData DamageDataSpec
---@return boolean
function AIGameLogic:damage(damageData)
  local data = DamageData:new(damageData)
  return not Damage:new(self, data):getBenefit()
end

local LoseHp = AIGameEvent:subclass("AIGameEvent.LoseHp")
fk.ai_events.LoseHp = LoseHp
function LoseHp:exec()
  local data = self.data
  local room = self.room
  local logic = room.logic

  if data.num == nil then
    data.num = 1
  elseif data.num < 1 then
    return false
  end

  logic:trigger(fk.PreHpLost, data.who, data)
  if data.num < 1 then
    data.prevented = true
  end
  if data.prevented then
    return true
  end

  if not room:changeHp(data.who, -data.num, "loseHp", data.skillName) then
    return true
  end

  logic:trigger(fk.HpLost, data.who, data)
  return true
end

---@param player ServerPlayer
---@param num integer
---@param skillName string
---@return boolean
function AIGameLogic:loseHp(player, num, skillName)
  local data = HpLostData:new{
    who = player,
    num = num,
    skillName = skillName,
  }
  return not LoseHp:new(self, data):getBenefit()
end

---@class AIGameEvent.Recover : AIGameEvent
---@field public data RecoverData
local Recover = AIGameEvent:subclass("AIGameEvent.Recover")
fk.ai_events.Recover = Recover
function Recover:exec()
  local RecoverData = self.data
  local logic = self.logic

  local who = RecoverData.who

  logic:trigger(fk.PreHpRecover, who, RecoverData)
  if RecoverData.num == 0 then
    RecoverData.prevented = true
  end
  if RecoverData.prevented then
    return true
  end

  RecoverData.num = math.min(RecoverData.num, who.maxHp - who.hp)

  if RecoverData.num < 1 then
    return true
  end

  if not logic:changeHp(who, RecoverData.num, "recover", RecoverData.skillName) then
    return true
  end

  logic:trigger(fk.HpRecover, who, RecoverData)
end

function AIGameLogic:recover(recoverDataSpec)
  local recoverData = RecoverData:new(recoverDataSpec)
  return not Recover:new(self, recoverData):getBenefit()
end

-- skill.lua

local SkillEffect = AIGameEvent:subclass("AIGameEvent.SkillEffect")
fk.ai_events.SkillEffect = SkillEffect
function SkillEffect:exec()
  local logic = self.logic
  local data = self.data
  local effect_cb, player, skill, skill_data = data.skill_cb, data.who, data.skill, data.skill_data
  local main_skill = skill.main_skill and skill.main_skill or skill

  logic:trigger(fk.SkillEffect, player, data)
  effect_cb()
  logic:trigger(fk.AfterSkillEffect, player, data)
end

function AIGameLogic:useSkill(player, skill, effect_cb, skill_data)
  local data = { ---@type SkillEffectDataSpec
    who = player,
    skill = skill,
    skill_cb = effect_cb,
    skill_data = skill_data or Util.DummyTable
  }
  return not SkillEffect:new(self, SkillEffectData:new(data)):getBenefit()
end

-- movecard.lua
local MoveCards = AIGameEvent:subclass("AIGameEvent.MoveCards")
fk.ai_events.MoveCards = MoveCards
function MoveCards:exec()
  local logic = self.logic
  local moveCardsData = self.data

  logic:trigger(fk.BeforeCardsMove, nil, moveCardsData)

  for _, data in ipairs(moveCardsData) do
    for _, info in ipairs(data.moveInfo or {}) do
      logic:applyMoveInfo(data, info)
    end
  end

  logic:trigger(fk.AfterCardsMove, nil, moveCardsData)
end

function AIGameLogic:getNCards(num, from)
  local cardIds = {}
  for _ = 1, num do
    table.insert(cardIds, 1)
  end
  return cardIds
end

--- 将填入room:moveCards的参数，根据情况转为正确的data（防止非法移动）
---@param self AIGameLogic
---@param ... CardsMoveInfo
---@return MoveCardsData[]
local function moveInfoTranslate(self, ...)
  local logic = self.logic
  local ret = {}
  for _, cardsMoveInfo in ipairs{ ... } do
    if #cardsMoveInfo.ids > 0 then
      ---@type MoveInfo[]
      local infos = {}
      for _, id in ipairs(cardsMoveInfo.ids) do
        table.insert(infos, {
          cardId = id,
          fromArea = self.ai.room:getCardArea(id),
          fromSpecialName = cardsMoveInfo.from and cardsMoveInfo.from:getPileNameOfId(id),
        })
      end
      if #infos > 0 then
        table.insert(ret, MoveCardsData:new {
          moveInfo = infos,
          from = cardsMoveInfo.from,
          to = cardsMoveInfo.to,
          toArea = cardsMoveInfo.toArea,
          moveReason = cardsMoveInfo.moveReason,
          proposer = cardsMoveInfo.proposer,
          skillName = cardsMoveInfo.skillName,
          moveVisible = cardsMoveInfo.moveVisible,
          specialName = cardsMoveInfo.specialName,
          specialVisible = cardsMoveInfo.specialVisible,
          drawPilePosition = cardsMoveInfo.drawPilePosition,
          moveMark = cardsMoveInfo.moveMark,
          visiblePlayers = cardsMoveInfo.visiblePlayers,
        })
      end
    end
  end
  return ret
end

function AIGameLogic:moveCards(...)
  local datas = moveInfoTranslate(self, ...)
  if #datas == 0 then
    return false
  end
  return not MoveCards:new(self, datas):getBenefit()
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
    from = who,
    toArea = Card.DiscardPile,
    skillName = skillName,
    moveReason = fk.ReasonRecast,
    proposer = who,
  })
  return self:drawCards(who, #card_ids, skillName)
end

-- usecard.lua

local UseCard = AIGameEvent:subclass("AIGameEvent.UseCard")
fk.ai_events.UseCard = UseCard
function UseCard:exec()
  local logic = self.logic
  local useCardData = self.data

  if useCardData and useCardData.card and useCardData.card.skill then
    local skill_ai = fk.ai_skills[useCardData.card.skill.name]
    if skill_ai then skill_ai:onUse(logic, useCardData) end
  end

  logic:trigger(fk.PreCardUse, useCardData.from, useCardData)
  logic:moveCardTo(useCardData.card, Card.Processing, nil, fk.ReasonUse)

  for _, event in ipairs({ fk.AfterCardUseDeclared, fk.AfterCardTargetDeclared, fk.CardUsing }) do
    if not useCardData.toCard and #useCardData.tos == 0 then
      break
    end

    logic:trigger(event, useCardData.from, useCardData)
    if event == fk.CardUsing then
      logic:doCardUseEffect(useCardData)
    end
  end

  logic:trigger(fk.CardUseFinished, useCardData.from, useCardData)
  logic:moveCards{
    fromArea = Card.Processing,
    toArea = Card.DiscardPile,
    ids = Card:getIdList(useCardData.card),
    moveReason = fk.ReasonUse,
  }
end

---@param useCardData UseCardDataSpec
function AIGameLogic:useCard(useCardData)
  local new_data
  new_data = UseCardData:new(useCardData)
  return not UseCard:new(self, new_data):getBenefit()
end

---@param players ServerPlayer[]
---@return ServerPlayer[]
function AIGameLogic:deadPlayerFilter(players)
  local newPlayers = {}
  for _, player in ipairs(players) do
    if player:isAlive() then
      table.insert(newPlayers, player)
    end
  end

  return newPlayers
end

AIGameLogic.doCardUseEffect = GameEventWrappers.doCardUseEffect

local CardEffect = AIGameEvent:subclass("AIGameEvent.CardEffect")
fk.ai_events.CardEffect = CardEffect
function CardEffect:exec()
  local cardEffectData = self.data
  local room = self.room
  local logic = room.logic

  if cardEffectData.card.skill:aboutToEffect(room, cardEffectData) then
    return true
  end
  for _, event in ipairs({ fk.PreCardEffect, fk.BeforeCardEffect, fk.CardEffecting }) do
    local function effectCancellOutCheck(effect)
      if effect.isCancellOut then
        logic:trigger(fk.CardEffectCancelledOut, effect.from, effect)
        if effect.isCancellOut then
          return true
        end
      end

      if
        not effect.toCard and
        (
          not (effect.to and effect.to:isAlive())
          or #room:deadPlayerFilter(effect.tos) == 0
        )
      then
        return true
      end

      if effect:isNullified() then
        return true
      end
    end

    if effectCancellOutCheck(cardEffectData) then
      return true
    end

    if event == fk.PreCardEffect then
      logic:trigger(event, cardEffectData.from, cardEffectData)
    else
      logic:trigger(event, cardEffectData.to, cardEffectData)
    end

    if effectCancellOutCheck(cardEffectData) then
      return true
    end

    room:handleCardEffect(event, cardEffectData)
  end
end

function AIGameLogic:doCardEffect(CardEffectData)
  return not CardEffect:new(self, CardEffectData):getBenefit()
end

---@param event CardEffectEvent
---@param cardEffectEvent CardEffectData
function AIGameLogic:handleCardEffect(event, cardEffectEvent)
  -- 不考虑闪与无懈 100%生效
  -- 闪和无懈早该重构重构了
  if event == fk.CardEffecting then
    if cardEffectEvent.card.skill then
      local data = { ---@type SkillEffectDataSpec
        who = cardEffectEvent.from,
        skill = cardEffectEvent.card.skill,
        skill_cb = function()
          local skill = cardEffectEvent.card.skill
          local ai = fk.ai_skills[skill.name]
          if ai then
            ai:onEffect(self, cardEffectEvent)
          end
        end,
        skill_data = Util.DummyTable
      }
      SkillEffect:new(self, SkillEffectData:new(data)):getBenefit()
    end
  end
end

-- judge.lua

local Judge = AIGameEvent:subclass("AIGameEvent.Judge")
fk.ai_events.Judge = Judge
function Judge:exec()
  local data = self.data
  local logic = self.logic
  local who = data.who

  -- data.isJudgeEvent = true
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

---@param data JudgeDataSpec
function AIGameLogic:judge(data)
  return Judge:new(self, JudgeData:new(data)):getBenefit()
end

-- 暂时不模拟改判。

return AIGameLogic, AIGameEvent
