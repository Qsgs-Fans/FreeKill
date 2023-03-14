---@alias Event integer

fk.NonTrigger = 1
fk.GameStart = 2
fk.TurnStart = 3
fk.EventPhaseStart = 4
fk.EventPhaseProceeding = 5
fk.EventPhaseEnd = 6
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

fk.Empty28 = 28
fk.Empty29 = 29

fk.TurnedOver = 30
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
fk.BeforeGameOverJudge = 63
fk.GameOverJudge = 64
fk.GameFinished = 65

fk.AskForCardUse = 66
fk.AskForCardResponse = 67

fk.StartPindian = 68
fk.PindianCardsDisplayed = 69
fk.PindianResultConfirmed = 70
fk.PindianFinished = 71

fk.NumOfEvents = 72
