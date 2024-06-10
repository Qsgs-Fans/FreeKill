-- SPDX-License-Identifier: GPL-3.0-or-later

--- GameMode用来描述一个游戏模式。
---
--- 可以参考欢乐斗地主。
---
---@class GameMode: Object
---@field public name string @ 游戏模式名
---@field public minPlayer integer @ 最小玩家数
---@field public maxPlayer integer @ 最大玩家数
---@field public rule? TriggerSkill @ 规则（通过技能完成，通常用来为特定角色及特定时机提供触发事件）
---@field public logic? fun(): GameLogic @ 逻辑（通过function完成，通常用来初始化、分配身份及座次）
---@field public whitelist? string[] @ 白名单
---@field public blacklist? string[] @ 黑名单
local GameMode = class("GameMode")

--- 构造函数，不可随意调用。
---@param name string @ 游戏模式名
---@param min integer @ 最小玩家数
---@param max integer @ 最大玩家数
function GameMode:initialize(name, min, max)
  self.name = name
  self.minPlayer = math.max(min, 2)
  self.maxPlayer = math.min(max, 12)
end

---@param victim ServerPlayer @ 死者
---@return string @ 胜者阵营
function GameMode:getWinner(victim)
  if not victim.surrendered and victim.rest > 0 then
    return ""
  end

  local room = victim.room
  local winner = ""
  local alive = table.filter(room.players, function(p)
    return not p.surrendered and not (p.dead and p.rest == 0)
  end)

  if victim.role == "lord" then
    if #alive == 1 and alive[1].role == "renegade" then
      winner = "renegade"
    else
      winner = "rebel"
    end
  elseif victim.role ~= "loyalist" then
    local lord_win = true
    for _, p in ipairs(alive) do
      if p.role == "rebel" or p.role == "renegade" then
        lord_win = false
        break
      end
    end
    if lord_win then
      winner = "lord+loyalist"
    end
  end

  return winner
end

---@param playedTime number @ 游戏时长（单位：秒）
---@return table
function GameMode:surrenderFunc(playedTime)
  return {}
end

---@param room Room @ 游戏房间
---@return boolean
function GameMode:countInFunc(room)
  return true
end

-- 修改角色的属性
---@param player ServerPlayer
---@return table @ 返回表，键为调整的角色属性，值为调整后的属性
function GameMode:getAdjustedProperty (player)
  local list = {}
  if player.role == "lord" and player.role_shown and #player.room.players > 4 then
    list.hp = player.hp + 1
    list.maxHp = player.maxHp + 1
  end
  return list
end

return GameMode
