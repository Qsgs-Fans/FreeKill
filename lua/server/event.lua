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

fk.PindianVerifying = 28
fk.Pindian = 29

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

fk.NumOfEvents = 41
