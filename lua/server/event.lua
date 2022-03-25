local EVENTS = {
  "GameStart",

  "PhaseChanging",
  "PhaseStart",
  "PhaseProceeding",
  "PhaseEnd",

  "PreCardUse",
  "AfterCardUseDeclared",
  "AfterCardTargetDeclared",
  "CardUsing",
  "CardUseFinished",
}

GameEvent = Util:createEnum(EVENTS)
