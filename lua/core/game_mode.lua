-- SPDX-License-Identifier: GPL-3.0-or-later

--- GameMode用来描述一个游戏模式。
---
--- 可以参考欢乐斗地主。
---
---@class GameMode: Object
---@field public name string @ 游戏模式名
---@field public minPlayer integer @ 最小玩家数
---@field public maxPlayer integer @ 最大玩家数
---@field public rule TriggerSkill @ 规则（通过技能完成，通常用来为特定角色及特定时机提供触发事件）
---@field public logic fun() @ 逻辑（通过function完成，通常用来初始化、分配身份及座次）
---@field public surrenderFunc fun()
local GameMode = class("GameMode")

--- 构造函数，不可随意调用。
---@param name string @ 游戏模式名
---@param min integer @ 最小玩家数
---@param max integer @ 最大玩家数
function GameMode:initialize(name, min, max)
  self.name = name
  self.minPlayer = math.max(min, 2)
  self.maxPlayer = math.min(max, 8)
end

return GameMode
