
--- JudgeData 判定的数据
---@class JudgeDataSpec
---@field public who ServerPlayer @ 判定者
---@field public pattern string|table<string, any> @ 判定成功的条件，若为表，则为该次判定的所有可能判定及对应数据
---@field public reason string @ 判定原因，技能名
---@field public card? Card @ 当前判定牌
---@field public results? table @ 判定结果，为nil则说明判定被终止
---@field public skipDrop? boolean @ 是否不进入弃牌堆

--- 判定的数据
---@class JudgeData: JudgeDataSpec, TriggerData
JudgeData = TriggerData:subclass("JudgeData")

--- 构造函数
function JudgeData:initialize(spec)
  TriggerData.initialize(self, spec)
  self.pattern = spec.pattern or "."
  spec.matchPattern = JudgeData.matchPattern
end

---@class JudgeEvent: TriggerEvent
---@field data JudgeData
local JudgeEvent = TriggerEvent:subclass("JudgeEvent")

---@class fk.StartJudge: JudgeEvent
fk.StartJudge = JudgeEvent:subclass("fk.StartJudge")
---@class fk.AskForRetrial: JudgeEvent
fk.AskForRetrial = JudgeEvent:subclass("fk.AskForRetrial")
---@class fk.FinishRetrial: JudgeEvent
fk.FinishRetrial = JudgeEvent:subclass("fk.FinishRetrial")
---@class fk.FinishJudge: JudgeEvent
fk.FinishJudge = JudgeEvent:subclass("fk.FinishJudge")

---@alias JudgeTrigFunc fun(self: TriggerSkill, event: JudgeEvent,
---  target: ServerPlayer, player: ServerPlayer, data: JudgeData): any

---@class SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: JudgeEvent,
---  data: TrigSkelSpec<JudgeTrigFunc>, attr: TrigSkelAttribute?): SkillSkeleton

-- 判定成功
function JudgeData:matchPattern()
  if self.results then
    return table.contains(self.results, "good")
  end
  return false
end

-- 转化判定条件为表格形式
function JudgeData:initializePattern()
  if type(self.pattern) == "string" then
    local pattern_str = self.pattern
    self.pattern = {
      [pattern_str] = "good",
      ["else"] = "bad",
    }
  end
end

-- 添加一条判定分支
function JudgeData:addPattern(pattern, result)
  self:initializePattern()
  self.pattern[pattern] = result
end

-- 反转判定——good变bad，bad变good，其余不变
function JudgeData:reversePattern()
  self:initializePattern()
  local tmp = {}
  for pattern, result in pairs(self.pattern) do
    if result == "good" then
      tmp[pattern] = "bad"
    elseif result == "bad" then
      tmp[pattern] = "good"
    else
      tmp[pattern] = result
    end
  end
  self.pattern = tmp
end
