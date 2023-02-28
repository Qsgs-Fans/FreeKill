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

-- TODO: fix this
GameEvent.BreakEvent = 999

