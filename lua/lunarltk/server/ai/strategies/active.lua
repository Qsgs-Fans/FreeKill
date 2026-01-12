local AIStrategy = require "lunarltk.server.ai.strategy"

---@class AI.ActiveStrategy : AIStrategy
---@field use_value number 给牌时，考虑一下使用的价值
---@field use_priority number 出牌阶段，考虑一下使用的优先度
local ActiveStrategy = AIStrategy:subclass("AI.ActiveStrategy")

function ActiveStrategy:initialize()
  AIStrategy.initialize(self)

  self.use_value = 0
  self.use_priority = 0
end

-- 这是默认的think 要求用户实现几个接口供我跑收益程序
-- 当然用户可以自己实现think 直接返回think结果

---@return [integer[], ServerPlayer[]?, any]?, number?
function ActiveStrategy:think(ai)
  local skill = Fk.skills[self.skill_name] --[[@as ActiveSkill]]
  if not skill then return end

  -- 思考interaction选什么呢
  if skill.interaction then
  end

  -- 思考卡牌选什么呢

  -- 思考目标选什么呢

  -- 遍历一下可选项 算收益

  -- return { cards, targets, idata }, 0
end

-- 搜索类方法：怎么走下一步？
-- choose系列的函数都是用作迭代算子的，因此它们需要能计算出所有的可选情况
-- （至少是需要所有的以及觉得可行的可选情况，如果另外写AI的话）
-- 但是也没办法一次性算出所有情况并拿去遍历。为此，只要每次调用都算出和之前不一样的解法就行了

local function cardsAcceptable(ai)
  return ai:okButtonEnabled() or (#ai:getEnabledTargets() > 0)
  -- return false
end

local function cardsString(cards)
  table.sort(cards)
  return table.concat(cards, '+')
end

---@param val [integer[], ServerPlayer[]?, any]?
function ActiveStrategy:convertThinkResult(val)
  if not val then return end
  return {
    card = {
      skill = self.skill_name,
      subcards = val[1],
    },
    targets = table.map(val[2] or Util.DummyTable, Util.IdMapper),
    interaction = val[3],
  }
end

--- 针对一般技能的选卡搜索方案
--- 注意选真牌时面板的合法性逻辑完全不同 对真牌就没必要如此遍历了
---@param ai SmartAI
function ActiveStrategy:searchCardSelections(ai)
  local searched = {}
  local function search()
    local selected = ai:getSelectedCards() -- 搜索起点
    local to_remove = selected[#selected]
    -- 空情况也考虑一下
    if ai._debug then
      verbose(1, "当前已选：%s", table.concat(selected, "|"))
    end
    if #selected == 0 and not searched[""] and cardsAcceptable(ai) then
      searched[""] = true
      return {}
    end
    if ai._debug then
      verbose(1, "当前可选：%s", table.concat(ai:getEnabledCards(), "|"))
    end
    -- 从所有可能的下一步找
    for _, cid in ipairs(ai:getEnabledCards()) do
      table.insert(selected, cid)
      local str = cardsString(selected)
      if not searched[str] then
        searched[str] = true
        ai:selectCard(cid, true)
        if cardsAcceptable(ai) then
          return ai:getSelectedCards()
        end
        local ret = search()
        if ret then return ret end
        ai:selectCard(cid, false)
      end
      table.removeOne(selected, cid)
    end

    -- 返回上一步，考虑再次搜索
    if not to_remove then return nil end
    ai:selectCard(to_remove, false)
    return search()
  end
  return search
end

local function targetString(targets)
  local ids = table.map(targets, Util.IdMapper)
  table.sort(ids)
  return table.concat(ids, '+')
end

---@param ai SmartAI
function ActiveStrategy:searchTargetSelections(ai)
  local searched = {}
  local function search()
    local selected = ai:getSelectedTargets() -- 搜索起点
    local to_remove = selected[#selected]
    -- 空情况也考虑一下
    if ai._debug then
      verbose(1, "当前已选：%s", table.concat(table.map(selected, Util.IdMapper), "|"))
    end
    if #selected == 0 and not searched[""] and ai:okButtonEnabled() then
      searched[""] = true
      return {}
    end
    if ai._debug then
      verbose(1, "当前可选：%s", table.concat(table.map(ai:getEnabledTargets(), Util.IdMapper), "|"))
    end
    -- 从所有可能的下一步找
    for _, target in ipairs(ai:getEnabledTargets()) do
      table.insert(selected, target)
      local str = targetString(selected)
      if not searched[str] then
        searched[str] = true
        ai:selectTarget(target, true)
        if ai:okButtonEnabled() then
          return ai:getSelectedTargets()
        end
        local ret = search()
        if ret then return ret end
        ai:selectTarget(target, false)
      end
      table.removeOne(selected, target)
    end

    -- 返回上一步，考虑再次搜索
    if not to_remove then return nil end
    ai:selectTarget(to_remove, false)
    return search()
  end
  return search
end

---@param spec {
---  think?: (fun(self: AI.ActiveStrategy, ai: SmartAI): [ integer[], ServerPlayer[]?, any ]?, number?),
---  use_value?: number,
---  use_priority?: number,
---}
---@return AI.ActiveStrategy
local function newActiveStrategy(spec)
  local ret = ActiveStrategy:new()
  if spec.think then
    ret.think = spec.think
  end

  if spec.use_value then ret.use_value = spec.use_value end
  if spec.use_priority then ret.use_priority = spec.use_priority end

  return ret
end

return {
  ActiveStrategy,
  newActiveStrategy,
}
