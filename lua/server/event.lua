---@alias Event integer

fk.NonTrigger = 1
fk.GameStart = 2
fk.TurnStart = 3
fk.EventPhaseStart = 4
fk.EventPhaseProceeding = 5
fk.EventPhaseEnd = 6
fk.EventPhaseChanging = 7
fk.EventPhaseSkipping = 8

fk.DrawNCards = 9
fk.AfterDrawNCards = 10
fk.DrawInitialCards = 11
fk.AfterDrawInitialCards = 12

fk.PreHpRecover = 13
fk.HpRecover = 14
fk.PreHpLost = 15
fk.HpLost = 16
fk.HpChanged = 17
fk.MaxHpChanged = 18

fk.EventLoseSkill = 19
fk.EventAcquireSkill = 20

fk.StartJudge = 21
fk.AskForRetrial = 22
fk.FinishRetrial = 23
fk.FinishJudge = 24

fk.PindianVerifying = 25
fk.Pindian = 26

fk.TurnedOver = 27
fk.ChainStateChanged = 28

fk.NumOfEvents = 29
