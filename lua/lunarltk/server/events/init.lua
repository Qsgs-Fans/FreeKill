---@diagnostic disable
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Definitions of game events

-- 某类事件对应的结束事件，其id刚好就是那个事件的相反数
-- GameEvent.EventFinish = -1

--- 给Room.lua瘦身：一系列GameEvent的封装
---@class GameEventWrappers: MiscEventWrappers, HpEventWrappers, DeathEventWrappers, MoveEventWrappers, UseCardEventWrappers, SkillEventWrappers, JudgeEventWrappers, PindianEventWrappers
local GameEventWrappers = {} -- mixin

local tmp
tmp = require "lunarltk.server.events.misc"
GameEvent.ChangeProperty = tmp[1]
table.assign(GameEventWrappers, tmp[2])

tmp = require "lunarltk.server.events.hp"
GameEvent.ChangeHp = tmp[1]
GameEvent.Damage = tmp[2]
GameEvent.LoseHp = tmp[3]
GameEvent.Recover = tmp[4]
GameEvent.ChangeMaxHp = tmp[5]
table.assign(GameEventWrappers, tmp[6])

tmp = require "lunarltk.server.events.death"
GameEvent.Dying = tmp[1]
GameEvent.Death = tmp[2]
GameEvent.Revive = tmp[3]
table.assign(GameEventWrappers, tmp[4])

tmp = require "lunarltk.server.events.movecard"
GameEvent.MoveCards = tmp[1]
table.assign(GameEventWrappers, tmp[2])

tmp = require "lunarltk.server.events.usecard"
GameEvent.UseCard = tmp[1]
GameEvent.RespondCard = tmp[2]
GameEvent.CardEffect = tmp[3]
table.assign(GameEventWrappers, tmp[4])

tmp = require "lunarltk.server.events.skill"
GameEvent.SkillEffect = tmp[1]
table.assign(GameEventWrappers, tmp[2])

tmp = require "lunarltk.server.events.judge"
GameEvent.Judge = tmp[1]
table.assign(GameEventWrappers, tmp[2])

tmp = require "lunarltk.server.events.gameflow"
GameEvent.DrawInitial = tmp[1]
GameEvent.Round = tmp[2]
GameEvent.Turn = tmp[3]
GameEvent.Phase = tmp[4]

tmp = require "lunarltk.server.events.pindian"
GameEvent.Pindian = tmp[1]
table.assign(GameEventWrappers, tmp[2])

return GameEventWrappers
