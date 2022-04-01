---@alias Event integer

fk.createEnum(fk, {
    "NonTrigger",

    "GameStart",
    "TurnStart",
    "EventPhaseStart",
    "EventPhaseProceeding",
    "EventPhaseEnd",
    "EventPhaseChanging",
    "EventPhaseSkipping",

    "NumOfEvents"
})
