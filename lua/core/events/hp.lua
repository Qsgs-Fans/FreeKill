
--- HpChangedData 描述和一次体力变化有关的数据
---@class HpChangedDataSpec
---@field public who ServerPlayer @ 体力变化的角色
---@field public num integer @ 体力变化量，可能是正数或者负数
---@field public shield_lost? integer @ 护甲变化量
---@field public reason string @ 体力变化原因
---@field public skillName string @ 引起体力变化的技能名
---@field public damageEvent? DamageData @ 引起这次体力变化的伤害数据
---@field public preventDying? boolean @ 是否阻止本次体力变更流程引发濒死流程
---@field public prevented boolean? @ 体力变化是否被防止

--- 描述和一次体力变化有关的数据
---@class HpChangedData: HpChangedDataSpec, TriggerData
HpChangedData = TriggerData:subclass("HpChangedData")

--- HpLostData 描述跟失去体力有关的数据
---@class HpLostDataSpec
---@field public who ServerPlayer @ 失去体力的角色
---@field public num integer @ 失去体力的数值
---@field public skillName string @ 导致这次失去的技能名
---@field public prevented boolean? @ 失去体力是否被防止

--- 描述跟失去体力有关的数据
---@class HpLostData: HpLostDataSpec, TriggerData
HpLostData = TriggerData:subclass("HpLostData")

--- 防止失去体力
function HpLostData:preventHpLost()
  self.num = 0
  self.prevented = true
end

--- MaxHpChangedData 描述跟体力上限变化有关的数据
---@class MaxHpChangedDataSpec
---@field public who ServerPlayer @ 改变体力上限的角色
---@field public num integer @ 体力上限变化量，可能是正数或者负数
---@field public prevented boolean? @ 改变体力上限是否被防止

--- 描述跟体力上限变化有关的数据
---@class MaxHpChangedData: MaxHpChangedDataSpec, TriggerData
MaxHpChangedData = TriggerData:subclass("MaxHpChangedData")

--- 防止改变体力上限
function MaxHpChangedData:preventMaxHpChange()
  self.num = 0
  self.prevented = true
end

---@alias DamageType integer

fk.NormalDamage = 1
fk.ThunderDamage = 2
fk.FireDamage = 3
fk.IceDamage = 4

--- DamageData 描述和伤害事件有关的数据
---@class DamageDataSpec
---@field public from? ServerPlayer @ 伤害来源
---@field public to ServerPlayer @ 伤害目标
---@field public damage integer @ 伤害值
---@field public card? Card @ 造成伤害的牌
---@field public chain? boolean @ 伤害是否是铁索传导的伤害
---@field public damageType? DamageType @ 伤害属性
---@field public skillName? string @ 造成本次伤害的技能名
---@field public beginnerOfTheDamage? boolean @ 是否是本次铁索传导的起点
---@field public by_user? boolean @ 是否由卡牌直接生效造成的伤害
---@field public chain_table? ServerPlayer[] @ 处于连环状态的角色表
---@field public isVirtualDMG? boolean @ 是否是虚拟伤害
---@field public dealtRecorderId integer? @ “实际造成的伤害”中对应的事件ID
---@field public prevented boolean? @ 伤害是否被防止

--- 描述和伤害事件有关的数据
---@class DamageData: DamageDataSpec, TriggerData
DamageData = TriggerData:subclass("DamageData")

--- 改变伤害事件的伤害值
---@param num integer 伤害值改变量
function DamageData:changeDamage(num)
  self.damage = self.damage + num
  if self.damage < 1 then
    self:preventDamage()
  end
end

--- 防止伤害
function DamageData:preventDamage()
  self.damage = 0
  self.prevented = true
end

--- RecoverData 描述和回复体力有关的数据
---@class RecoverDataSpec
---@field public who ServerPlayer @ 回复体力的角色
---@field public num integer @ 回复值
---@field public recoverBy? ServerPlayer @ 此次回复的回复来源
---@field public skillName? string @ 因何种技能而回复
---@field public card? Card @ 造成此次回复的卡牌
---@field public prevented boolean? @ 回复体力是否被防止

--- 描述和回复体力有关的数据
---@class RecoverData: RecoverDataSpec, TriggerData
RecoverData = TriggerData:subclass("RecoverData")

--- 改变回复事件的回复值
---@param num integer 回复值改变量
function RecoverData:changeRecover(num)
  self.num = self.num + num
  if self.num < 1 then
    self:preventRecover()
  end
end

--- 防止回复
function RecoverData:preventRecover()
  self.num = 0
  self.prevented = true
end

---@class HpChangedEvent: TriggerEvent
---@field data HpChangedData
local HpChangedEvent = TriggerEvent:subclass("HpChangedEvent")

--- 改变体力值前
---@class fk.BeforeHpChanged: HpChangedEvent
fk.BeforeHpChanged = HpChangedEvent:subclass("fk.BeforeHpChanged")
--- 改变体力值后
---@class fk.HpChanged: HpChangedEvent
fk.HpChanged = HpChangedEvent:subclass("fk.HpChanged")

---@class DamageEvent: TriggerEvent
---@field data DamageData
local DamageEvent = TriggerEvent:subclass("DamageEvent")

--- 伤害结算开始前
---@class fk.PreDamage: DamageEvent
fk.PreDamage = DamageEvent:subclass("fk.PreDamage")
--- 造成伤害时
---@class fk.DamageCaused: DamageEvent
fk.DamageCaused = DamageEvent:subclass("fk.DamageCaused")
--- 造成伤害时②（用于确定伤害值，如改为固定伤害值或防止伤害）
---@class fk.DetermineDamageCaused: DamageEvent
fk.DetermineDamageCaused = DamageEvent:subclass("fk.DetermineDamageCaused")
--- 受到伤害时
---@class fk.DamageInflicted: DamageEvent
fk.DamageInflicted = DamageEvent:subclass("fk.DamageInflicted")
--- 受到伤害时②（用于确定伤害值，如改为固定伤害值或防止伤害）
---@class fk.DetermineDamageInflicted: DamageEvent
fk.DetermineDamageInflicted = DamageEvent:subclass("fk.DetermineDamageInflicted")
--- 造成伤害后
---@class fk.Damage: DamageEvent
fk.Damage = DamageEvent:subclass("fk.Damage")
--- 受到伤害后
---@class fk.Damaged: DamageEvent
fk.Damaged = DamageEvent:subclass("fk.Damaged")
--- 伤害结算结束后
---@class fk.DamageFinished: DamageEvent
fk.DamageFinished = DamageEvent:subclass("fk.DamageFinished")

---@class HpLostEvent: TriggerEvent
---@field public data HpLostData
local HpLostEvent = TriggerEvent:subclass("HpLostEvent")

--- 失去体力结算开始前
---@class fk.PreHpLost: HpLostEvent
fk.PreHpLost = HpLostEvent:subclass("fk.PreHpLost")
--- 失去体力后
---@class fk.HpLost: HpLostEvent
fk.HpLost = HpLostEvent:subclass("fk.HpLost")

---@class RecoverEvent: TriggerEvent
---@field public data RecoverData
local RecoverEvent = TriggerEvent:subclass("RecoverEvent")

--- 回复体力结算开始前
---@class fk.PreHpRecover: RecoverEvent
fk.PreHpRecover = RecoverEvent:subclass("fk.PreHpRecover")
--- 回复体力后
---@class fk.HpRecover: RecoverEvent
fk.HpRecover = RecoverEvent:subclass("fk.HpRecover")

---@class MaxHpChangedEvent: TriggerEvent
---@field public data MaxHpChangedData
local MaxHpChangedEvent = TriggerEvent:subclass("MaxHpChangedEvent")

--- 改变体力上限前
---@class fk.BeforeMaxHpChanged: MaxHpChangedEvent
fk.BeforeMaxHpChanged = MaxHpChangedEvent:subclass("fk.BeforeMaxHpChanged")
--- 改变体力上限后
---@class fk.MaxHpChanged: MaxHpChangedEvent
fk.MaxHpChanged = MaxHpChangedEvent:subclass("fk.MaxHpChanged")

-- 注释环节

---@alias HpChangedTrigFunc fun(self: TriggerSkill, event: HpChangedEvent,
---  target: ServerPlayer, player: ServerPlayer, data: HpChangedData): any
---@alias HpLostTrigFunc fun(self: TriggerSkill, event: HpLostEvent,
---  target: ServerPlayer, player: ServerPlayer, data: HpLostData): any
---@alias DamageTrigFunc fun(self: TriggerSkill, event: DamageEvent,
---  target: ServerPlayer, player: ServerPlayer, data: DamageData): any
---@alias RecoverTrigFunc fun(self: TriggerSkill, event: RecoverEvent,
---  target: ServerPlayer, player: ServerPlayer, data: RecoverData): any
---@alias MaxHpChangedTrigFunc fun(self: TriggerSkill, event: MaxHpChangedEvent,
---  target: ServerPlayer, player: ServerPlayer, data: MaxHpChangedData): any

---@class DamageSkelAttr: TrigSkelAttribute

---@class SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: HpChangedEvent,
---  data: TrigSkelSpec<HpChangedTrigFunc>, attr: TrigSkelAttribute?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: HpLostEvent,
---  data: TrigSkelSpec<HpLostTrigFunc>, attr: DamageSkelAttr?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: DamageEvent,
---  data: TrigSkelSpec<DamageTrigFunc>, attr: DamageSkelAttr?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: RecoverEvent,
---  data: TrigSkelSpec<RecoverTrigFunc>, attr: DamageSkelAttr?): SkillSkeleton
---@field public addEffect fun(self: SkillSkeleton, key: MaxHpChangedEvent,
---  data: TrigSkelSpec<MaxHpChangedTrigFunc>, attr: TrigSkelAttribute?): SkillSkeleton

function DamageEvent:breakCheck()
  return self.data.damage < 1 or self.data.prevented
end
