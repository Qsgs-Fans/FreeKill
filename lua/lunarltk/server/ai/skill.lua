--- 关于某个技能如何在AI中处理。
---
--- 相关方法分为三类，分别是如何搜索、如何计算收益、如何进行收益推理
---
--- 所谓搜索，就是如何确定下一步该选择哪张卡牌/哪名角色等。
--- 默认情况下，AI选择收益最高的选项作为下一步，如果遇到了死胡同就返回考虑下一种。
--- 所谓死胡同就是什么都不能点击，也不能点确定的状态，必须取消某些的选择。
---
--- 所谓的收益计算就是估算这个选项在这个技能的语境下，他大概会带来多少收益。
--- 限于算力，我们不能编写太复杂的收益计算。默认情况下，收益可以通过推理完成，
--- 而推理的步骤需要Modder向AI给出提示。
---
--- 所谓的给出提示就是上面的“如何进行收益推理”。拓展可以针对点击某张卡牌或者
--- 点击某个角色，告诉AI这么点击了可能会发生某种事件。AI根据事件以及游戏内包含的
--- 其他技能进行计算，得出收益值。若不想让它这样计算，也可以在上一步直接指定
--- 固定的收益值。
---
--- 所谓的“可能发生某种事件”大致类似GameEvent，但是内部功能大幅简化了（因为
--- 只是用于简单的推理）。详见同文件夹下event.lua内容。
---@class SkillAI: Object
---@field public skill Skill
local SkillAI = class("SkillAI")

---@param skill string
function SkillAI:initialize(skill)
  self.skill = Fk.skills[skill]
end

--- 收益估计
---@param ai SmartAI
---@return integer?
function SkillAI:getEstimatedBenefit(ai)
  return 0
end

-- API类：SmartAI顶层会调用以下函数

--- 面板类思考函数，囊括了出牌阶段、询问使用打出以及askForUseActiveSkill
---
--- 要返回一个结果，以及收益值
---@param ai SmartAI
---@return any?, integer?
function SkillAI:think(ai) end

-- 剩下的都对应一种command，见函数名

---@param ai SmartAI
---@param target ServerPlayer @ 被选牌的人
---@param flag any @ 用"hej"三个字母的组合表示能选择哪些区域, h 手牌区, e - 装备区, j - 判定区
---@param prompt? string @ 提示信息
---@return integer, integer?
function SkillAI:thinkForCardChosen(ai, target, flag, prompt)
end

---@param ai SmartAI
---@param skill_name string @ 技能名
---@param prompt? string @ 提示信息
---@return boolean, integer?
function SkillAI:thinkForSkillInvoke(ai, skill_name, prompt)
end

---@param ai SmartAI
---@param choices string[] @ 可选选项列表
---@param skill_name? string @ 技能名
---@param prompt? string @ 提示信息
---@param all_choices? string[] @ 所有选项（不可选变灰）
---@return string, integer?
function SkillAI:thinkForChoice(ai, choices, skill_name, prompt, all_choices)
end

-- 搜索类方法：怎么走下一步？
-- choose系列的函数都是用作迭代算子的，因此它们需要能计算出所有的可选情况
-- （至少是需要所有的以及觉得可行的可选情况，如果另外写AI的话）
-- 但是也没办法一次性算出所有情况并拿去遍历。为此，只要每次调用都算出和之前不一样的解法就行了

local function cardsAcceptable(smart_ai)
  return smart_ai:okButtonEnabled() or (#smart_ai:getEnabledTargets() > 0)
  -- return false
end

local function cardsString(cards)
  table.sort(cards)
  return table.concat(cards, '+')
end

--- 针对一般技能的选卡搜索方案
--- 注意选真牌时面板的合法性逻辑完全不同 对真牌就没必要如此遍历了
---@param smart_ai SmartAI
function SkillAI:searchCardSelections(smart_ai)
  local searched = {}
  local function search()
    local selected = smart_ai:getSelectedCards() -- 搜索起点
    local to_remove = selected[#selected]
    -- 空情况也考虑一下
    verbose(1, "当前已选：%s", table.concat(selected, "|"))
    if #selected == 0 and not searched[""] and cardsAcceptable(smart_ai) then
      searched[""] = true
      return {}
    end
    verbose(1, "当前可选：%s", table.concat(smart_ai:getEnabledCards(), "|"))
    -- 从所有可能的下一步找
    for _, cid in ipairs(smart_ai:getEnabledCards()) do
      table.insert(selected, cid)
      local str = cardsString(selected)
      if not searched[str] then
        searched[str] = true
        smart_ai:selectCard(cid, true)
        if cardsAcceptable(smart_ai) then
          return smart_ai:getSelectedCards()
        end
        local ret = search()
        if ret then return ret end
        smart_ai:selectCard(cid, false)
      end
      table.removeOne(selected, cid)
    end

    -- 返回上一步，考虑再次搜索
    if not to_remove then return nil end
    smart_ai:selectCard(to_remove, false)
    return search()
  end
  return search
end

local function targetString(targets)
  local ids = table.map(targets, Util.IdMapper)
  table.sort(ids)
  return table.concat(ids, '+')
end

---@param smart_ai SmartAI
function SkillAI:searchTargetSelections(smart_ai)
  local searched = {}
  local function search()
    local selected = smart_ai:getSelectedTargets() -- 搜索起点
    -- local to_remove = selected[#selected]
    -- 空情况也考虑一下
    verbose(1, "当前已选：%s", table.concat(table.map(selected, Util.IdMapper), "|"))
    if #selected == 0 and not searched[""] and smart_ai:okButtonEnabled() then
      searched[""] = true
      return {}
    end
    verbose(1, "当前可选：%s", table.concat(table.map(smart_ai:getEnabledTargets(), Util.IdMapper), "|"))
    -- 从所有可能的下一步找
    for _, target in ipairs(smart_ai:getEnabledTargets()) do
      table.insert(selected, target)
      local str = targetString(selected)
      if not searched[str] then
        searched[str] = true
        smart_ai:selectTarget(target, true)
        if smart_ai:okButtonEnabled() then
          return smart_ai:getSelectedTargets()
        end
        local ret = search()
        if ret then return ret end
        smart_ai:selectTarget(target, false)
      end
      table.removeOne(selected, target)
    end

    -- 返回上一步，考虑再次搜索
    if not to_remove then return nil end
    smart_ai:selectTarget(to_remove, false)
    return search()
  end
  return search
end

---@param ai SmartAI
function SkillAI:chooseInteraction(ai) end

---@param ai SmartAI
function SkillAI:chooseCards(ai) end

---@param ai SmartAI
---@return any, integer?
function SkillAI:chooseTargets(ai) end

-- 流程模拟类方法：为了让AIGameLogic开心

--- 对触发技生效的模拟
---@param logic AIGameLogic
---@param event Event @ TriggerEvent
---@param target ServerPlayer @ Player who triggered this event
---@param player ServerPlayer @ Player who is operating
---@param data any @ useful data of the event
function SkillAI:onTriggerUse(logic, event, target, player, data) end

--- 对主动技生效/卡牌被使用时的模拟
---@param logic AIGameLogic
---@param event UseCardData | SkillEffectData
function SkillAI:onUse(logic, event) end

--- 对卡牌生效的模拟
---@param logic AIGameLogic
---@param cardEffectEvent CardEffectData | SkillEffectData
function SkillAI:onEffect(logic, cardEffectEvent) end

--- 最后效仿一下fk_ex故事

---@class SkillAISpec
---@field estimated_benefit? integer|fun(self: SkillAI, ai: SmartAI): integer?
---@field think? fun(self: SkillAI, ai: SmartAI): any?, integer?
---@field think_card_chosen? fun(self: SkillAI, ai: SmartAI, target: ServerPlayer, flag: string, prompt: string?): integer, integer?
---@field think_skill_invoke? fun(self: SkillAI, ai: SmartAI, skill_name: string, prompt: string?): boolean, integer?
---@field think_choice? fun(self: SkillAI, ai: SmartAI, choices:string[], skill_name: string, prompt: string, all_choices: string[]): string, integer @ 选择的思考。返回选项名和收益
---@field choose_interaction? fun(self: SkillAI, ai: SmartAI): boolean?
---@field choose_cards? fun(self: SkillAI, ai: SmartAI): boolean?
---@field choose_targets? fun(self: SkillAI, ai: SmartAI): any, integer?
---@field on_trigger_use? fun(self: SkillAI, logic: AIGameLogic, event: Event, target: ServerPlayer?, player: ServerPlayer, data: any)
---@field on_use? fun(self: SkillAI, logic: AIGameLogic, effect: CardEffectData | SkillEffectData)
---@field on_effect? fun(self: SkillAI, logic: AIGameLogic, effect: CardEffectData | SkillEffectData)

--- 关于某个触发技在AI中如何影响基于事件的收益推理。
---
--- 类似于真正的触发技，这种技能AI也需要指定触发时机，以及在某个时机之下
--- 如何进行收益计算。收益计算中亦可返回true，表明事件被这个技能终止，
--- 也就是不再进行后续其他技能的计算。
---
--- 触发技本身又会不断触发新的事件，比如刚烈反伤、反馈拿牌等。对于衍生事件
--- 亦可进一步进行推理，但是AI会限制自己的搜索深度，所以推理结果不一定准确。
---@class TriggerSkillAI
---@field public skill TriggerSkill
local TriggerSkillAI = class("TriggerSkillAI")

---@param skill string
function TriggerSkillAI:initialize(skill)
  self.skill = Fk.skills[skill]
end

--- 获取触发技对收益评测的影响，通过基于logic触发更多模拟事件来模拟收益的变化
---
--- 返回true表示打断后续收益判断逻辑
---@param logic AIGameLogic
---@param event TriggerEvent
---@param target ServerPlayer?
---@param player ServerPlayer
---@param data any @ 事件数据
---@return boolean?
function TriggerSkillAI:getCorrect(logic, event, target, player, data)
end

---@class TriggerSkillAISpec
---@field correct_func fun(self: TriggerSkillAI, logic: AIGameLogic, event: TriggerEvent, target: ServerPlayer?, player: ServerPlayer, data: any): boolean?

return { SkillAI, TriggerSkillAI }
