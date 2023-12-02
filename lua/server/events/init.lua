-- SPDX-License-Identifier: GPL-3.0-or-later

-- Definitions of game events

-- 某类事件对应的结束事件，其id刚好就是那个事件的相反数
-- GameEvent.EventFinish = -1

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
GameEvent.CardEffect = 20
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

-- 20 = CardEffect
GameEvent.ChangeProperty = 21
dofile "lua/server/events/misc.lua"

-- TODO: fix this
GameEvent.BreakEvent = 999

for _, l in ipairs(Fk._custom_events) do
  local name, p, m, c, e = l.name, l.p, l.m, l.c, l.e
  GameEvent.prepare_funcs[name] = p
  GameEvent.functions[name] = m
  GameEvent.cleaners[name] = c
  GameEvent.exit_funcs[name] = e
end

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
  [GameEvent.CardEffect] = "GameEvent.CardEffect",
  [GameEvent.SkillEffect] = "GameEvent.SkillEffect",
  [GameEvent.Judge] = "GameEvent.Judge",
  [GameEvent.DrawInitial] = "GameEvent.DrawInitial",
  [GameEvent.Round] = "GameEvent.Round",
  [GameEvent.Turn] = "GameEvent.Turn",
  [GameEvent.Phase] = "GameEvent.Phase",
  [GameEvent.Pindian] = "GameEvent.Pindian",

  [GameEvent.ChangeProperty] = "GameEvent.ChangeProperty",

  [GameEvent.BreakEvent] = "GameEvent.BreakEvent",
}

function GameEvent.static:translate(id)
  local ret = eventTranslations[id]
  if not ret then ret = id end
  return ret
end
