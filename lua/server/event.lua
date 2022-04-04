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
fk.HpChanged = 19
fk.MaxHpChanged = 20

fk.EventLoseSkill = 21
fk.EventAcquireSkill = 22

fk.StartJudge = 23
fk.AskForRetrial = 24
fk.FinishRetrial = 25
fk.FinishJudge = 26

fk.PindianVerifying = 27
fk.Pindian = 28

fk.TurnedOver = 29
fk.ChainStateChanged = 30

fk.NumOfEvents = 31
