-- SPDX-License-Identifier: GPL-3.0-or-later

MarkEnum = {}

---跳过觉醒标记(值为技能名通过+连接)
MarkEnum.StraightToWake = "_straight_to_wake"

---转换技状态标记前缀（整体为前缀+转换技技能）
MarkEnum.SwithSkillPreName = "__switcher_"
---使命技状态标记前缀（整体为前缀+使命技技能）
MarkEnum.QuestSkillPreName = "__questPre_"

---增加标记值数量的手牌上限
MarkEnum.AddMaxCards = "AddMaxCards"
---于本回合内增加标记值数量的手牌上限
MarkEnum.AddMaxCardsInTurn = "AddMaxCards-turn"
---减少标记值数量的手牌上限
MarkEnum.MinusMaxCards = "MinusMaxCards"
---于本回合内减少标记值数量的手牌上限
MarkEnum.MinusMaxCardsInTurn = "MinusMaxCards-turn"

---使用牌无次数限制
MarkEnum.BypassTimesLimit = "BypassTimesLimit"
---使用牌无距离限制
MarkEnum.BypassDistancesLimit = "BypassDistancesLimit"
---对其使用牌无次数限制
MarkEnum.BypassTimesLimitTo = "BypassTimesLimitTo"
---对其使用牌无距离限制
MarkEnum.BypassDistancesLimitTo = "BypassDistancesLimitTo"
---非锁定技失效
MarkEnum.UncompulsoryInvalidity = "UncompulsoryInvalidity"
---失效技能键值表，键为失效技能，值为控制技能表（用``Room:invalidateSkill``和``Room:validateSkill``控制）
MarkEnum.InvalidSkills = "InvalidSkills"
---不可明置（值为表，m - 主将, d - 副将）
MarkEnum.RevealProhibited = "RevealProhibited"
---不计入距离、座次
MarkEnum.PlayerRemoved = "PlayerRemoved"
---不能调整手牌
MarkEnum.SortProhibited = "SortProhibited"
---无效/无视防具
MarkEnum.MarkArmorNullified = "mark__armor_nullified"
MarkEnum.MarkArmorInvalidFrom = "mark__armor_invalid_from"
MarkEnum.MarkArmorInvalidTo = "mark__armor_invalid_to"

---@alias TempMarkSuffix "-round" | "-turn" | "-phase" | "-noclear"

---角色标记的清除标记后缀
---
---phase：阶段结束后
---
---turn：回合结束后
---
---round：轮次结束后
---
---noclear: 不能被一键清除（如死亡时清理标记）
MarkEnum.TempMarkSuffix = { "-phase", "-turn", "-round", "-noclear" }

---卡牌标记的清除标记后缀
---
---phase：阶段结束后
---
---turn：回合结束后
---
---round：轮次结束后
---
---inhand：离开手牌区后
---
---inarea：离开标记值指定的特定区域后
MarkEnum.CardTempMarkSuffix = { "-phase", "-turn", "-round",
                                "-inhand", "-inarea", "-public" }

---销毁

-- 进入弃牌堆销毁 例OL蒲元
MarkEnum.DestructIntoDiscard = "__destr_discard"

-- 离开自己的装备区销毁 例新服刘晔
MarkEnum.DestructOutMyEquip = "__destr_my_equip"

-- 进入非装备区销毁(可在装备区/处理区移动) 例OL冯方女
MarkEnum.DestructOutEquip = "__destr_equip"
