-- SPDX-License-Identifier: GPL-3.0-or-later

MarkEnum = {}

---@field StraightToWake string @ 跳过觉醒标记(值为技能名通过+连接)
MarkEnum.StraightToWake = "_straight_to_wake"

---@field SwithSkillPreName string @ 转换技状态标记前缀（整体为前缀+转换技技能）
MarkEnum.SwithSkillPreName = "__switcher_"
---@field SwithSkillPreName string @ 转换技状态标记前缀（整体为前缀+转换技技能）
MarkEnum.QuestSkillPreName = "__questPre_"

---@field AddMaxCards string @ 增加标记值数量的手牌上限
MarkEnum.AddMaxCards = "AddMaxCards"
---@field AddMaxCardsInTurn string @ 于本回合内增加标记值数量的手牌上限
MarkEnum.AddMaxCardsInTurn = "AddMaxCards-turn"
---@field MinusMaxCards string @ 减少标记值数量的手牌上限
MarkEnum.MinusMaxCards = "MinusMaxCards"
---@field AddMaxCards string @ 于本回合内减少标记值数量的手牌上限
MarkEnum.MinusMaxCardsInTurn = "MinusMaxCards-turn"

---@field UncompulsoryInvalidity string @ 非锁定技失效，可带清除标记后缀
MarkEnum.UncompulsoryInvalidity = "uncompulsoryInvalidity"

---@field TempMarkSuffix string[] @ 各种清除标记后缀
MarkEnum.TempMarkSuffix = { "-phase", "-turn", "-round" }
