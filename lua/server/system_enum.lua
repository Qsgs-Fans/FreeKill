-- SPDX-License-Identifier: GPL-3.0-or-later

---@alias PlayerId integer

--- CardsMoveInfo 一组牌的移动信息
---@class CardsMoveInfo
---@field public ids integer[] @ 移动卡牌ID数组
---@field public from? integer @ 移动来源玩家ID
---@field public to? integer @ 移动终点玩家ID
---@field public toArea? CardArea @ 移动终点区域
---@field public moveReason? CardMoveReason @ 移动原因
---@field public proposer? integer @ 移动执行者
---@field public skillName? string @ 移动技能名
---@field public moveVisible? boolean @ 控制移动是否可见
---@field public specialName? string @ 若终点区域为PlayerSpecial，则存至对应私人牌堆内
---@field public specialVisible? boolean @ 控制上述创建私人牌堆后是否令其可见
---@field public drawPilePosition? integer @ 移至牌堆的索引位置，值为-1代表置入牌堆底，或者牌堆牌数+1也为牌堆底
---@field public moveMark? table|string @ 移动后自动赋予标记，格式：{标记名(支持-inarea后缀，移出值代表区域后清除), 值}
---@field public visiblePlayers? integer|integer[] @ 控制移动对特定角色可见（在moveVisible为false时生效）

--- MoveInfo 一张牌的来源信息
---@class MoveInfo
---@field public cardId integer
---@field public fromArea CardArea
---@field public fromSpecialName? string

--- CardsMoveStruct 一次完整移动
---@class CardsMoveStruct
---@field public moveInfo MoveInfo[] @ 移动信息
---@field public from? integer @ 移动来源玩家ID
---@field public to? integer @ 移动终点玩家ID
---@field public toArea CardArea @ 移动终点区域
---@field public moveReason CardMoveReason @ 移动原因
---@field public proposer? integer @ 移动执行者
---@field public skillName? string @ 移动技能名
---@field public moveVisible? boolean @ 控制移动是否可见
---@field public specialName? string @ 若终点区域为PlayerSpecial，则存至对应私人牌堆内
---@field public specialVisible? boolean @ 控制上述创建私人牌堆后是否令其可见
---@field public drawPilePosition? integer @ 移至牌堆的索引位置，值为-1代表置入牌堆底，或者牌堆牌数+1也为牌堆底
---@field public moveMark? table|string @ 移动后自动赋予标记，格式：{标记名(支持-inarea后缀，移出值代表区域后清除), 值}
---@field public visiblePlayers? integer|integer[] @ 控制移动对特定角色可见（在moveVisible为false时生效）

--- PindianResult 拼点结果
---@class PindianResult
---@field public toCard Card @ 被拼点者所使用的牌
---@field public winner? ServerPlayer @ 赢家，可能不存在

--- HpChangedData 描述和一次体力变化有关的数据
---@class HpChangedData
---@field public num integer @ 体力变化量，可能是正数或者负数
---@field public shield_lost integer|nil
---@field public reason string @ 体力变化原因
---@field public skillName string @ 引起体力变化的技能名
---@field public damageEvent? DamageStruct @ 引起这次体力变化的伤害数据
---@field public preventDying? boolean @ 是否阻止本次体力变更流程引发濒死流程

--- HpLostData 描述跟失去体力有关的数据
---@class HpLostData
---@field public num integer @ 失去体力的数值
---@field public skillName string @ 导致这次失去的技能名

--- MaxHpChangedData 描述跟体力上限变化有关的数据
---@class MaxHpChangedData
---@field public num integer @ 体力上限变化量，可能是正数或者负数

--- DamageType 伤害的属性
---@alias DamageType integer

fk.NormalDamage = 1
fk.ThunderDamage = 2
fk.FireDamage = 3
fk.IceDamage = 4

--- DamageStruct 描述和伤害事件有关的数据。
---@class DamageStruct
---@field public from? ServerPlayer @ 伤害来源
---@field public to ServerPlayer @ 伤害目标
---@field public damage integer @ 伤害值
---@field public card? Card @ 造成伤害的牌
---@field public chain? boolean @ 伤害是否是铁索传导的伤害
---@field public damageType? DamageType @ 伤害的属性
---@field public skillName? string @ 造成本次伤害的技能名
---@field public beginnerOfTheDamage? boolean @ 是否是本次铁索传导的起点
---@field public by_user? boolean @ 是否由卡牌直接生效造成的伤害
---@field public chain_table? ServerPlayer[] @ 铁索连环表

--- RecoverStruct 描述和回复体力有关的数据。
---@class RecoverStruct
---@field public who ServerPlayer @ 回复体力的角色
---@field public num integer @ 回复值
---@field public recoverBy? ServerPlayer @ 此次回复的回复来源
---@field public skillName? string @ 因何种技能而回复
---@field public card? Card @ 造成此次回复的卡牌

--- DyingStruct 描述和濒死事件有关的数据
---@class DyingStruct
---@field public who integer @ 濒死角色
---@field public damage DamageStruct @ 造成此次濒死的伤害数据
---@field public ignoreDeath? boolean @ 是否不进行死亡结算

--- DeathStruct 描述和死亡事件有关的数据
---@class DeathStruct
---@field public who integer @ 死亡角色
---@field public damage DamageStruct @ 造成此次死亡的伤害数据

--- askForUseCard中的extra_data
---@class UseExtraData
---@field public must_targets? integer[] @ 必须选择这些目标？
---@field public include_targets? integer[] @ 必须选其中一个目标？
---@field public exclusive_targets? integer[] @ 只能选择这些目标？
---@field public bypass_distances? boolean @ 无距离限制？
---@field public bypass_times? boolean @ 无次数限制？
---@field public playing? boolean @ (AI专用) 出牌阶段？

--- CardUseStruct 使用卡牌的数据
---@class CardUseStruct
---@field public from integer @ 使用者
---@field public tos TargetGroup @ 角色目标组
---@field public card Card @ 卡牌本牌
---@field public toCard? Card @ 卡牌目标
---@field public responseToEvent? CardUseStruct @ 响应事件目标
---@field public nullifiedTargets? integer[] @ 对这些角色无效
---@field public extraUse? boolean @ 是否不计入次数
---@field public disresponsiveList? integer[] @ 这些角色不可响应此牌
---@field public unoffsetableList? integer[] @ 这些角色不可抵消此牌
---@field public additionalDamage? integer @ 额外伤害值（如酒之于杀）
---@field public additionalRecover? integer @ 额外回复值
---@field public extra_data? any @ 额外数据（如目标过滤等）
---@field public customFrom? integer @ 新使用者
---@field public cardsResponded? Card[] @ 响应此牌的牌
---@field public prohibitedCardNames? string[] @ 这些牌名的牌不可响应此牌
---@field public damageDealt? table<PlayerId, number> @ 此牌造成的伤害
---@field public additionalEffect? integer @ 额外结算次数
---@field public noIndicate? boolean @ 隐藏指示线

--- AimStruct 处理使用牌目标的数据
---@class AimStruct
---@field public from integer @ 使用者
---@field public card Card @ 卡牌本牌
---@field public tos AimGroup @ 总角色目标
---@field public to integer @ 当前角色目标
---@field public subTargets? integer[] @ 子目标（借刀！）
---@field public targetGroup? TargetGroup @ 目标组
---@field public nullifiedTargets? integer[] @ 对这些角色无效
---@field public firstTarget boolean @ 是否是第一个目标
---@field public additionalDamage? integer @ 额外伤害值（如酒之于杀）
---@field public additionalRecover? integer @ 额外回复值
---@field public disresponsive? boolean @ 是否不可响应
---@field public unoffsetable? boolean @ 是否不可抵消
---@field public fixedResponseTimes? table<string, integer>|integer @ 额外响应请求
---@field public fixedAddTimesResponsors? integer[] @ 额外响应请求次数
---@field public additionalEffect? integer @额外结算次数

--- CardUseStruct 卡牌效果的数据
---@class CardEffectEvent
---@field public from? integer @ 使用者
---@field public to integer @ 角色目标
---@field public subTargets? integer[] @ 子目标（借刀！）
---@field public tos TargetGroup @ 目标组
---@field public card Card @ 卡牌本牌
---@field public toCard? Card @ 卡牌目标
---@field public responseToEvent? CardEffectEvent @ 响应事件目标
---@field public nullifiedTargets? integer[] @ 对这些角色无效
---@field public extraUse? boolean @ 是否不计入次数
---@field public disresponsiveList? integer[] @ 这些角色不可响应此牌
---@field public unoffsetableList? integer[] @ 这些角色不可抵消此牌
---@field public additionalDamage? integer @ 额外伤害值（如酒之于杀）
---@field public additionalRecover? integer @ 额外回复值
---@field public extra_data? any @ 额外数据（如目标过滤等）
---@field public customFrom? integer @ 新使用者
---@field public cardsResponded? Card[] @ 响应此牌的牌
---@field public disresponsive? boolean @ 是否不可响应
---@field public unoffsetable? boolean @ 是否不可抵消
---@field public isCancellOut? boolean @ 是否被抵消
---@field public fixedResponseTimes? table<string, integer>|integer @ 额外响应请求
---@field public fixedAddTimesResponsors? integer[] @ 额外响应请求次数
---@field public prohibitedCardNames? string[] @ 这些牌名的牌不可响应此牌

--- SkillEffectEvent 技能效果的数据
---@class SkillEffectEvent
---@field public from integer @ 使用者
---@field public tos integer[] @ 角色目标
---@field public cards integer[] @ 选择卡牌

--- JudgeStruct 判定的数据
---@class JudgeStruct
---@field public who ServerPlayer @ 判定者
---@field public card Card @ 当前判定牌
---@field public reason string @ 判定原因
---@field public pattern string @ 钩叉条件
---@field public skipDrop? boolean @ 是否不进入弃牌堆

--- CardResponseEvent 卡牌响应的数据
---@class CardResponseEvent
---@field public from integer @ 响应者
---@field public card Card @ 卡牌本牌
---@field public responseToEvent? CardEffectEvent @ 响应事件目标
---@field public skipDrop? boolean @ 是否不进入弃牌堆
---@field public customFrom? integer @ 新响应者

--- AskForCardUse 询问使用卡牌的数据
---@class AskForCardUse
---@field public user ServerPlayer @ 使用者
---@field public cardName string @ 烧条信息
---@field public pattern string @ 可用牌过滤
---@field public eventData CardEffectEvent @ 事件数据
---@field public extraData UseExtraData @ 额外数据
---@field public result? CardUseStruct @ 使用结果

--- AskForCardResponse 询问响应卡牌的数据
---@class AskForCardResponse
---@field public user ServerPlayer @ 响应者
---@field public cardName string @ 烧条信息
---@field public pattern string @ 可用牌过滤
---@field public extraData UseExtraData @ 额外数据
---@field public result? Card

--- PindianStruct 拼点的数据
---@class PindianStruct
---@field public from ServerPlayer @ 拼点发起者
---@field public tos ServerPlayer[] @ 拼点目标
---@field public fromCard Card @ 拼点发起者拼点牌
---@field public results table<integer, PindianResult> @ 结果
---@field public reason string @ 拼点原因

--- LogMessage 战报信息
---@class LogMessage
---@field public type string @ log主体
---@field public from? integer @ 要替换%from的玩家的id
---@field public to? integer[] @ 要替换%to的玩家id列表
---@field public card? integer[] @ 要替换%card的卡牌id列表
---@field public arg? any @ 要替换%arg的内容
---@field public arg2? any @ 要替换%arg2的内容
---@field public arg3? any @ 要替换%arg3的内容
---@field public toast? boolean @ 是否顺手把消息发送一条相同的toast

--- SkillUseStruct 使用技能的数据
---@class SkillUseStruct
---@field public skill Skill
---@field public willUse boolean

--- DrawCardStruct 摸牌的数据
---@class DrawCardStruct
---@field public who ServerPlayer @ 摸牌者
---@field public num number @ 摸牌数
---@field public skillName string @ 技能名
---@field public fromPlace "top"|"bottom" @ 摸牌的位置

--- 移动理由
---@alias CardMoveReason integer
fk.ReasonJustMove = 1
fk.ReasonDraw = 2
fk.ReasonDiscard = 3
fk.ReasonGive = 4
fk.ReasonPut = 5
fk.ReasonPutIntoDiscardPile = 6
fk.ReasonPrey = 7
fk.ReasonExchange = 8
fk.ReasonUse = 9
fk.ReasonResonpse = 10
fk.ReasonJudge = 11
fk.ReasonRecast = 12

--- 内置动画类型，理论上你可以自定义一个自己的动画类型（big会播放一段限定技动画）
---@alias AnimationType "special" | "drawcard" | "control" | "offensive" | "support" | "defensive" | "negative" | "masochism" | "switch" | "big"
