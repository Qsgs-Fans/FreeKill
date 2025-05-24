-- SPDX-License-Identifier: GPL-3.0-or-later

---@class CardSkill : ActiveSkill
---@field public distance_limit? integer @ 距离限制（牢代码）
---@field public offset_func? fun(self: CardSkill, room: Room, data: CardEffectData)  @ 卡牌的特殊抵消方式，覆盖原方式(杀问闪，锦囊问无懈)
local CardSkill = ActiveSkill:subclass("CardSkill")

function CardSkill:initialize(name, frequency)
  UsableSkill.initialize(self, name, frequency)
  self.min_target_num = 0
  self.max_target_num = 999
  self.min_card_num = 0
  self.max_card_num = 999
end

---------
-- 注：客户端函数，AI也会调用以作主动技判断
------- {

-- 判断该技能是否可主动发动
---@param player Player @ 使用者
---@param card? Card @ 牌，若该技能是卡牌的效果技能，需输入此值
---@param extra_data? UseExtraData @ 额外数据
---@return boolean?
function CardSkill:canUse(player, card, extra_data)
  return self:withinTimesLimit(player, Player.HistoryPhase, card)
end

-- 判断一张牌是否可被此技能选中
---@return boolean
function CardSkill:cardFilter()
  return false
end

-- 判断一名角色是否可被此技能选中
---@param player Player @ 使用者
---@param to_select Player @ 待选目标
---@param selected Player[] @ 已选目标
---@param selected_cards integer[] @ 已选牌
---@param card? Card @ 牌
---@param extra_data? UseExtraData @ 额外数据
---@return boolean?
function CardSkill:targetFilter(player, to_select, selected, selected_cards, card, extra_data)
  return false
end

-- 判断一名角色是否可成为此技能的目标
---@param player Player @ 使用者
---@param to_select Player @ 待选目标
---@param selected Player[] @ 已选目标
---@param card? Card @ 牌
---@param extra_data? any @ 额外数据
---@return boolean?
function CardSkill:modTargetFilter(player, to_select, selected, card, extra_data)
  --FIXME: 删除了distance_limit牢参数，看看如何适配牢代码
  return false
end

-- 获取使用此牌时的固定目标。注意，不需要进行任何合法性判断
---@param player Player @ 使用者
---@param card? Card @ 牌
---@param extra_data? UseExtraData @ 额外数据
---@return Player[]? @ 返回固定目标角色列表。若此牌可以选择目标，返回空表
function CardSkill:fixTargets(player, card, extra_data)
  return nil
end

-- 获得技能的最小目标数
---@param player Player @ 使用者
---@return number @ 最小目标数
function CardSkill:getMinTargetNum(player)
  local ret
  if self.target_num then ret = self.target_num
  else ret = self.min_target_num end

  if type(ret) == "function" then
    ret = ret(self, player)
  end
  return ret
end

-- 获得技能的最大目标数
---@param player Player @ 使用者
---@param card Card @ 牌
---@return number @ 最大目标数
function CardSkill:getMaxTargetNum(player, card)
  local ret
  if self.target_num then ret = self.target_num
  else ret = self.max_target_num end

  if type(ret) == "function" then
    ret = ret(self, player, card)
  end

  local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    local correct = skill:getExtraTargetNum(player, self, card)
    if correct == nil then correct = 0 end
    ret = ret + correct
  end
  return ret
end

-- 获得技能的最小卡牌数
---@param player Player @ 使用者
---@return number @ 最小卡牌数
function CardSkill:getMinCardNum(player)
  local ret
  if self.card_num then ret = self.card_num
  else ret = self.min_card_num end

  if type(ret) == "function" then
    ret = ret(self, player)
  end
  return ret
end

-- 获得技能的最大卡牌数
---@param player Player @ 使用者
---@return number @ 最大卡牌数
function CardSkill:getMaxCardNum(player)
  local ret
  if self.card_num then ret = self.card_num
  else ret = self.max_card_num end

  if type(ret) == "function" then
    ret = ret(self, player)
  end
  return ret
end

-- 判断一个技能是否可发动（也就是确认键是否可点击）。默认值为选择卡牌数和选择目标数均在允许范围内
-- 警告：没啥事别改
---@param player Player @ 使用者
---@param selected Player[] @ 已选目标
---@param selected_cards integer[] @ 已选牌
---@param card Card @ 牌
---@return boolean
function CardSkill:feasible(player, selected, selected_cards, card)
  return #selected >= self:getMinTargetNum(player) and #selected <= self:getMaxTargetNum(player, card)
    and #selected_cards >= self:getMinCardNum(player) and #selected_cards <= self:getMaxCardNum(player)
end

-- 获得技能的距离限制
---@param player Player @ 使用者
---@param card Card @ 使用卡牌
---@param to Player @ 目标
---@return number @ 距离限制
function CardSkill:getDistanceLimit(player, card, to)
  local ret = self.distance_limit or 0
  local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable
  for _, skill in ipairs(status_skills) do
    local correct = skill:getDistanceLimit(player, self, card, to)
    if correct == nil then correct = 0 end
    ret = ret + correct
  end
  return ret
end

-- 判断一个角色是否在技能的距离限制内
---@param player Player @ 使用者
---@param isattack boolean? @ 是否使用攻击距离
---@param card Card @ 使用卡牌
---@param to Player @ 目标
---@return boolean?
function CardSkill:withinDistanceLimit(player, isattack, card, to)
  if not to or player:distanceTo(to) < 1 then return false end
  local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable
  if not card and self.name:endsWith("_skill") then
    card = Fk:cloneCard(self.name:sub(1, #self.name - 6))
  end
  for _, skill in ipairs(status_skills) do
    if skill:bypassDistancesCheck(player, self, card, to) then return true end
  end

  local temp_suf = table.simpleClone(MarkEnum.TempMarkSuffix)
  local card_temp_suf = table.simpleClone(MarkEnum.CardTempMarkSuffix)

  ---@param object Card|Player
  ---@param markname string
  ---@param suffixes string[]
  ---@return boolean
  local function hasMark(object, markname, suffixes)
    if not object then return false end
    for mark, _ in pairs(object.mark) do
      if mark == markname then return true end
      if mark:startsWith(markname .. "-") then
        for _, suffix in ipairs(suffixes) do
          if mark:find(suffix, 1, true) then return true end
        end
      end
    end
    return false
  end

  return (isattack and player:inMyAttackRange(to)) or
  (player:distanceTo(to) <= self:getDistanceLimit(player, card, to)) or
  hasMark(card, MarkEnum.BypassDistancesLimit, card_temp_suf) or
  hasMark(player, MarkEnum.BypassDistancesLimit, temp_suf) or
  hasMark(to, MarkEnum.BypassDistancesLimitTo, temp_suf)
  -- (card and table.find(card_temp_suf, function(s)
  --   return card:getMark(MarkEnum.BypassDistancesLimit .. s) ~= 0
  -- end)) or
  -- (table.find(temp_suf, function(s)
  --   return player:getMark(MarkEnum.BypassDistancesLimit .. s) ~= 0
  -- end)) or
  -- (to and (table.find(temp_suf, function(s)
  --   return to:getMark(MarkEnum.BypassDistancesLimitTo .. s) ~= 0
  -- end)))
end



---@param room Room
---@param cardUseEvent UseCardData
function CardSkill:onUse(room, cardUseEvent) end

---@param room Room
---@param cardUseEvent UseCardData | SkillEffectEvent
---@param finished? boolean?
function CardSkill:onAction(room, cardUseEvent, finished) end

---@param room Room
---@param cardEffectEvent CardEffectData | SkillEffectData
function CardSkill:aboutToEffect(room, cardEffectEvent) end

---@param room Room
---@param cardEffectEvent CardEffectData
function CardSkill:onEffect(room, cardEffectEvent) end

-- 仅用于延时技能的卡牌技能。用于效果被抵消后的处理
---@param room Room
---@param cardEffectEvent CardEffectData
function CardSkill:onNullified(room, cardEffectEvent) end



-- 卡牌生效前，询问抵消（默认杀询问闪，锦囊询问无懈）
---@param room Room
---@param cardEffectData CardEffectData
function CardSkill:preEffect(room, cardEffectData)
  if
    cardEffectData.card.trueName == "slash" and
    not cardEffectData:isUnoffsetable(cardEffectData.to)
  then
    local loopTimes = cardEffectData:getResponseTimes()
    Fk.currentResponsePattern = "jink"

    for i = 1, loopTimes do
      local to = cardEffectData.to
      local prompt = ""
      if cardEffectData.from then
        if loopTimes == 1 then
          prompt = "#slash-jink:" .. cardEffectData.from.id
        else
          prompt = "#slash-jink-multi:" .. cardEffectData.from.id .. "::" .. i .. ":" .. loopTimes
        end
      end

      local params = { ---@type AskToUseCardParams
        pattern = "jink",
        skill_name = "jink",
        prompt = prompt,
        cancelable = true,
        event_data = cardEffectData
      }
      local use = room:askToUseCard(to, params)
      if use then
        --use.toCard = cardEffectData.card
        --use.responseToEvent = cardEffectData
        room:useCard(use)
      end

      if not cardEffectData.isCancellOut then
        break
      end

      cardEffectData.isCancellOut = i == loopTimes
    end
  elseif
    cardEffectData.card.type == Card.TypeTrick and
    not (cardEffectData.disresponsive or cardEffectData.unoffsetable) and
    not table.contains(cardEffectData.prohibitedCardNames or Util.DummyTable, "nullification")
  then
    local players = {}
    Fk.currentResponsePattern = "nullification"
    local cardCloned = Fk:cloneCard("nullification")
    for _, p in ipairs(room.alive_players) do
      if not p:prohibitUse(cardCloned) then
        local cards = p:getHandlyIds()
        for _, cid in ipairs(cards) do
          if
            Fk:getCardById(cid).trueName == "nullification" and
            (
              cardEffectData.use == nil or
              not (
                table.contains(cardEffectData.use.disresponsiveList or Util.DummyTable, p) or
                table.contains(cardEffectData.use.unoffsetableList or Util.DummyTable, p)
              )
            )
          then
            table.insert(players, p)
            break
          end
        end
        if not table.contains(players, p) then
          Self = p -- for enabledAtResponse
          for _, s in ipairs(table.connect(p.player_skills, rawget(p, "_fake_skills"))) do
            ---@cast s ViewAsSkill
            if
              s.pattern and
              Exppattern:Parse("nullification"):matchExp(s.pattern) and
              (
                cardEffectData.use == nil or
                not (
                  table.contains(cardEffectData.use.disresponsiveList or Util.DummyTable, p) or
                  table.contains(cardEffectData.use.unoffsetableList or Util.DummyTable, p)
                )
              )
            then
              table.insert(players, p)
              break
            end
          end
        end
      end
    end

    local prompt = ""
    if cardEffectData.to then
      prompt = "#AskForNullification::" .. cardEffectData.to.id .. ":" .. cardEffectData.card.name
    elseif cardEffectData.from then
      prompt = "#AskForNullificationWithoutTo:" .. cardEffectData.from.id .. "::" .. cardEffectData.card.name
    end

    local extra_data
    if #cardEffectData.tos > 1 then
      local parentUseEvent = room.logic:getCurrentEvent():findParent(GameEvent.UseCard)
      if parentUseEvent then
        extra_data = { useEventId = parentUseEvent.id, effectTo = cardEffectData.to.id }
      end
    end
    if #players > 0 and cardEffectData.card.trueName == "nullification" then
      room:animDelay(2)
    end
    local params = { ---@type AskToUseCardParams
      skill_name = "nullification",
      pattern = "nullification",
      prompt = prompt,
      cancelable = true,
      extra_data = extra_data,
      event_data = cardEffectData
    }
    local use = room:askToNullification(players, params)
    if use then
      use.toCard = cardEffectData.card
      use.responseToEvent = cardEffectData
      room:useCard(use)
    end
  end
  Fk.currentResponsePattern = nil
end


return CardSkill
