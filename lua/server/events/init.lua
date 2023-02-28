-- Definitions of game events

GameEvent.ChangeHp = 1
GameEvent.Damage = 2
GameEvent.LoseHp = 3
GameEvent.Recover = 4
GameEvent.ChangeMaxHp = 5
dofile "lua/server/events/hp.lua"

GameEvent.Dying = 6
GameEvent.Death = 7
--dofile "lua/server/events/death.lua"

-- TODO: fix this
GameEvent.BreakEvent = 999

