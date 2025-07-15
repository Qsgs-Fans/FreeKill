
--- JudgeData 判定的数据
---@class JudgeDataSpec
---@field public who ServerPlayer @ 判定者
---@field public pattern string @ 判定成功的条件
---@field public reason string @ 判定原因，技能名
---@field public card? Card? @ 当前判定牌
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
  if self.card then
    return self.card:matchPattern(self.pattern)
  end
  return false
end
