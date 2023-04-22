-- SPDX-License-Identifier: GPL-3.0-or-later

-- Definitions of game events

GameEvent.ChangeHp = 1
GameEvent.Damage = 2
GameEvent.LoseHp = 3
GameEvent.Recover = 4
GameEvent.ChangeMaxHp = 5
dofile "lua/server/events/hp.lua"

GameEvent.Dying = 6
GameEvent.Death = 7
dofile "lua/server/events/death.lua"

GameEvent.MoveCards = 8
dofile "lua/server/events/movecard.lua"

GameEvent.UseCard = 9
GameEvent.RespondCard = 10
dofile "lua/server/events/usecard.lua"

GameEvent.SkillEffect = 11
-- GameEvent.AddSkill = 12
-- GameEvent.LoseSkill = 13
dofile "lua/server/events/skill.lua"

GameEvent.Judge = 14
dofile "lua/server/events/judge.lua"

GameEvent.DrawInitial = 15
GameEvent.Round = 16
GameEvent.Turn = 17
GameEvent.Phase = 18
dofile "lua/server/events/gameflow.lua"

GameEvent.Pindian = 19
dofile "lua/server/events/pindian.lua"

-- TODO: fix this
GameEvent.BreakEvent = 999

local eventTranslations = {
  [GameEvent.ChangeHp] = "GameEvent.ChangeHp",
  [GameEvent.Damage] = "GameEvent.Damage",
  [GameEvent.LoseHp] = "GameEvent.LoseHp",
  [GameEvent.Recover] = "GameEvent.Recover",
  [GameEvent.ChangeMaxHp] = "GameEvent.ChangeMaxHp",
  [GameEvent.Dying] = "GameEvent.Dying",
  [GameEvent.Death] = "GameEvent.Death",
  [GameEvent.MoveCards] = "GameEvent.MoveCards",
  [GameEvent.UseCard] = "GameEvent.UseCard",
  [GameEvent.RespondCard] = "GameEvent.RespondCard",
  [GameEvent.SkillEffect] = "GameEvent.SkillEffect",
  [GameEvent.Judge] = "GameEvent.Judge",
  [GameEvent.DrawInitial] = "GameEvent.DrawInitial",
  [GameEvent.Round] = "GameEvent.Round",
  [GameEvent.Turn] = "GameEvent.Turn",
  [GameEvent.Phase] = "GameEvent.Phase",
  [GameEvent.Pindian] = "GameEvent.Pindian",

  [GameEvent.BreakEvent] = "GameEvent.BreakEvent",
}

function GameEvent.static:translate(id)
  return eventTranslations[id]
end
