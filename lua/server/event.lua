-- SPDX-License-Identifier: GPL-3.0-or-later

-- 列出所有触发时机。
-- 关于每个时机的详情请从文档中检索。

---@alias Event integer

fk.NonTrigger = 1
fk.GamePrepared = 78
fk.GameStart = 2
fk.BeforeTurnStart = 83
fk.TurnStart = 3
fk.TurnEnd = 73
fk.AfterTurnEnd = 84
fk.EventPhaseStart = 4
fk.EventPhaseProceeding = 5
fk.EventPhaseEnd = 6
fk.AfterPhaseEnd = 86
fk.EventPhaseChanging = 7
fk.EventPhaseSkipping = 8

fk.BeforeCardsMove = 9
fk.AfterCardsMove = 10

fk.DrawNCards = 11
fk.AfterDrawNCards = 12
fk.DrawInitialCards = 13
fk.AfterDrawInitialCards = 14

fk.PreHpRecover = 15
fk.HpRecover = 16
fk.PreHpLost = 17
fk.HpLost = 18
fk.BeforeHpChanged = 19
fk.HpChanged = 20
fk.MaxHpChanged = 21

fk.EventLoseSkill = 22
fk.EventAcquireSkill = 23

fk.StartJudge = 24
fk.AskForRetrial = 25
fk.FinishRetrial = 26
fk.FinishJudge = 27

fk.RoundStart = 28
fk.RoundEnd = 29

fk.BeforeTurnOver = 79
fk.TurnedOver = 30
fk.BeforeChainStateChange = 80
fk.ChainStateChanged = 31

fk.PreDamage = 32
fk.DamageCaused = 33
fk.DamageInflicted = 34
fk.Damage = 35
fk.Damaged = 36
fk.DamageFinished = 37

fk.EnterDying = 38
fk.Dying = 39
fk.AfterDying = 40

fk.PreCardUse = 41
fk.AfterCardUseDeclared = 42
fk.AfterCardTargetDeclared = 43
fk.CardUsing = 44
fk.BeforeCardUseEffect = 45
fk.TargetSpecifying = 46
fk.TargetConfirming = 47
fk.TargetSpecified = 48
fk.TargetConfirmed = 49
fk.CardUseFinished = 50

fk.PreCardRespond = 51
fk.CardResponding = 52
fk.CardRespondFinished = 53

fk.PreCardEffect = 54
fk.BeforeCardEffect = 55
fk.CardEffecting = 56
fk.CardEffectFinished = 57
fk.CardEffectCancelledOut = 58

fk.AskForPeaches = 59
fk.AskForPeachesDone = 60
fk.Death = 61
fk.BuryVictim = 62
fk.Deathed = 63
fk.BeforeGameOverJudge = 64
fk.GameOverJudge = 65
fk.GameFinished = 66

fk.AskForCardUse = 67
fk.AskForCardResponse = 68

fk.StartPindian = 69
fk.PindianCardsDisplayed = 70
fk.PindianResultConfirmed = 71
fk.PindianFinished = 72

-- 73 = TurnEnd
fk.AfterDrawPileShuffle = 74

fk.BeforeTriggerSkillUse = 75

fk.BeforeDrawCard = 76

fk.CardShown = 77

-- 78 = GamePrepared

-- 79 = BeforeTurnOver
-- 80 = BeforeChainStateChange

fk.SkillEffect = 81
fk.AfterSkillEffect = 82

-- 83 = PreTurnStart
-- 84 = AfterTurnEnd
-- 85 = xxx
-- 86 = AfterPhaseEnd

fk.AreaAborted = 87
fk.AreaResumed = 88

fk.GeneralRevealed = 89
fk.GeneralHidden = 90

fk.NumOfEvents = 91
--[[
local events = {
  "NonTrigger",
  "GamePrepared",
  "GameStart",
  "BeforeTurnStart",
  "TurnStart",
  "TurnEnd",
  "AfterTurnEnd",
  "EventPhaseStart",
  "EventPhaseProceeding",
  "EventPhaseEnd",
  "AfterPhaseEnd",
  "EventPhaseChanging",
  "EventPhaseSkipping",

  "BeforeCardsMove",
  "AfterCardsMove",

  "DrawNCards",
  "AfterDrawNCards",
  "DrawInitialCards",
  "AfterDrawInitialCards",

  "PreHpRecover",
  "HpRecover",
  "PreHpLost",
  "HpLost",
  "BeforeHpChanged",
  "HpChanged",
  "MaxHpChanged",

  "EventLoseSkill",
  "EventAcquireSkill",

  "StartJudge",
  "AskForRetrial",
  "FinishRetrial",
  "FinishJudge",

  "RoundStart",
  "RoundEnd",
  "BeforeTurnOver",
  "TurnedOver",
  "BeforeChainStateChange",
  "ChainStateChanged",

  "PreDamage",
  "DamageCaused",
  "DamageInflicted",
  "Damage",
  "Damaged",
  "DamageFinished",

  "EnterDying",
  "Dying",
  "AfterDying",

  "PreCardUse",
  "AfterCardUseDeclared",
  "AfterCardTargetDeclared",
  "CardUsing",
  "BeforeCardUseEffect",
  "TargetSpecifying",
  "TargetConfirming",
  "TargetSpecified",
  "TargetConfirmed",
  "CardUseFinished",

  "PreCardRespond",
  "CardResponding",
  "CardRespondFinished",

  "PreCardEffect",
  "BeforeCardEffect",
  "CardEffecting",
  "CardEffectFinished",
  "CardEffectCancelledOut",

  "AskForPeaches",
  "AskForPeachesDone",
  "Death",
  "BuryVictim",
  "Deathed",
  "BeforeGameOverJudge",
  "GameOverJudge",
  "GameFinished",

  "AskForCardUse",
  "AskForCardResponse",

  "StartPindian",
  "PindianCardsDisplayed",
  "PindianResultConfirmed",
  "PindianFinished",

  "AfterDrawPileShuffle",

  "BeforeTriggerSkillUse",

  "BeforeDrawCard",

  "CardShown",

  "SkillEffect",
  "AfterSkillEffect",

  "AreaAborted",
  "AreaResumed",

  "GeneralRevealed",
  "GeneralHidden",

  "NumOfEvents"
}
for i, event in ipairs(events) do
  fk[event] = i
end --]]
