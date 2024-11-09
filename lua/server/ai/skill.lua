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
---@field public skill ActiveSkill
local SkillAI = class("SkillAI")

--- 收益估计
---@param ai SmartAI
---@return integer?
function SkillAI:getEstimatedBenefit(ai) end

--- 要返回一个结果，以及收益值
---@param ai SmartAI
---@return any?, integer?
function SkillAI:think(ai) end

---@param skill string
function SkillAI:initialize(skill)
  self.skill = Fk.skills[skill]
end

-- 搜索类方法：怎么走下一步？

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
---@param event CardUseStruct | SkillEffectEvent
function SkillAI:onUse(logic, event) end

--- 对卡牌生效的模拟
---@param logic AIGameLogic
---@param cardEffectEvent CardEffectEvent | SkillEffectEvent
function SkillAI:onEffect(logic, cardEffectEvent) end

--- 最后效仿一下fk_ex故事
---@class SkillAISpec
---@field estimated_benefit? integer|fun(self: SkillAI, ai: SmartAI): integer?
---@field think? fun(self: SkillAI, ai: SmartAI): any?, integer?
---@field choose_interaction? fun(self: SkillAI, ai: SmartAI): boolean?
---@field choose_cards? fun(self: SkillAI, ai: SmartAI): boolean?
---@field choose_targets? fun(self: SkillAI, ai: SmartAI): any, integer?
---@field on_trigger_use? fun(self: SkillAI, logic: AIGameLogic, event: Event, target: ServerPlayer?, player: ServerPlayer, data: any)
---@field on_use? fun(self: SkillAI, logic: AIGameLogic, effect: SkillEffectEvent | CardEffectEvent)
---@field on_effect? fun(self: SkillAI, logic: AIGameLogic, effect: SkillEffectEvent | CardEffectEvent)

return SkillAI
