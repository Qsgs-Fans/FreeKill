-- SPDX-License-Identifier: GPL-3.0-or-later

-- Definitions of game events

-- 某类事件对应的结束事件，其id刚好就是那个事件的相反数
-- GameEvent.EventFinish = -1

local tmp
tmp = require "server.events.misc"
GameEvent.Game = tmp[1]
GameEvent.ChangeProperty = tmp[2]
GameEvent.ClearEvent = tmp[3]

tmp = require "server.events.hp"
GameEvent.ChangeHp = tmp[1]
GameEvent.Damage = tmp[2]
GameEvent.LoseHp = tmp[3]
GameEvent.Recover = tmp[4]
GameEvent.ChangeMaxHp = tmp[5]

tmp = require "server.events.death"
GameEvent.Dying = tmp[1]
GameEvent.Death = tmp[2]
GameEvent.Revive = tmp[3]

tmp = require "server.events.movecard"
GameEvent.MoveCards = tmp

tmp = require "server.events.usecard"
GameEvent.UseCard = tmp[1]
GameEvent.RespondCard = tmp[2]
GameEvent.CardEffect = tmp[3]

tmp = require "server.events.skill"
GameEvent.SkillEffect = tmp

tmp = require "server.events.judge"
GameEvent.Judge = tmp

tmp = require "server.events.gameflow"
GameEvent.DrawInitial = tmp[1]
GameEvent.Round = tmp[2]
GameEvent.Turn = tmp[3]
GameEvent.Phase = tmp[4]

tmp = require "server.events.pindian"
GameEvent.Pindian = tmp

for _, l in ipairs(Fk._custom_events) do
  local name, p, m, c, e = l.name, l.p, l.m, l.c, l.e
  GameEvent.prepare_funcs[name] = p
  GameEvent.functions[name] = m
  GameEvent.cleaners[name] = c
  GameEvent.exit_funcs[name] = e
end
