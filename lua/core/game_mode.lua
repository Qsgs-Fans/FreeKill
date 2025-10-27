-- SPDX-License-Identifier: GPL-3.0-or-later

-- 呃，怎么办呢。。

--- GameMode用来描述一个游戏模式。
---
--- 可以参考欢乐斗地主。
---
---@class GameMode: Object
---@field public name string @ 游戏模式名
---@field public minPlayer integer @ 最小玩家数
---@field public maxPlayer integer @ 最大玩家数
---@field public minComp integer @ 最小电脑数
---@field public maxComp integer @ 最大电脑数
---@field public rule? string @ 规则（通过技能完成，通常用来为特定角色及特定时机提供触发事件）
---@field public logic? fun(): GameLogic @ 逻辑（通过function完成，通常用来初始化、分配身份及座次）
---@field public whitelist? string[] | fun(self: GameMode, pkg: Package): boolean? @ 白名单
---@field public blacklist? string[] | fun(self: GameMode, pkg: Package): boolean? @ 黑名单
---@field public main_mode? string @ 主模式名（用于判断此模式是否为某模式的衍生）
---@field public game_name? string @ 哪款桌游？默认lunarltk
---@field ui_settings any
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

-- 判断胜利者的函数，若不为""，则游戏存在胜利者（一般会结束游戏）
---@param victim ServerPlayer @ 死者
---@return string @ 胜者阵营
function GameMode:getWinner(victim)
  if not victim.surrendered and victim.rest > 0 then
    return ""
  end

  local room = victim.room
  local winner = ""
  local alive = table.filter(room.players, function(p)
    return not p.surrendered and not (p.dead and p.rest == 0) and p.role ~= "civilian"
  end)

  if victim.role == "lord" then
    if #alive == 1 and alive[1].role == "renegade" then
      winner = "renegade"
    else
      winner = "rebel+rebel_chief"
    end
  elseif victim.role ~= "loyalist" then
    local lord_win = true
    for _, p in ipairs(alive) do
      if p.role == "rebel" or p.role == "rebel_chief" or p.role == "renegade" then
        lord_win = false
        break
      end
    end
    if lord_win then
      winner = "lord+loyalist"
    end
  end

  if winner ~= "" then
    winner = winner.. "+civilian"
  end

  return winner
end

-- 判断什么时候可以投降的函数
---@param playedTime number @ 游戏时长（单位：秒）
---@return table
function GameMode:surrenderFunc(playedTime)
  return {}
end

-- 判断是否计入场次的函数
---@param room Room @ 游戏房间
---@return boolean
function GameMode:countInFunc(room)
  return true
end

-- 决定初始牌堆以及初始游戏外区域的函数
-- 需要返回两个数组，一个是牌堆，一个是游戏外（void）
function GameMode:buildDrawPile()
  local allCardIds = Fk:getAllCardIds()
  local void = {}

  for i = #allCardIds, 1, -1 do
    if Fk:getCardById(allCardIds[i]).is_derived then
      local id = allCardIds[i]
      table.remove(allCardIds, i)
      table.insert(void, id)
    end
  end

  return allCardIds, void
end

-- 根据模式设定修改角色的属性。例如，至少5人局时主公+1血和上限
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


-- 执行死亡奖惩
---@param victim ServerPlayer @ 死亡角色
---@param killer? ServerPlayer @ 击杀者，可能没有
function GameMode:deathRewardAndPunish (victim, killer)
  if not killer or killer.dead then return end
  if victim.role == "rebel" or victim.role == "rebel_chief" then
    killer:drawCards(3, "kill")
  elseif victim.role == "loyalist" and killer.role == "lord" then
    killer:throwAllCards("he")
  elseif victim.role == "civilian" then
    killer:drawCards(2, "kill")
  end
end

-- 敌友身份判断
---@param targetOne ServerPlayer | Player @ 待判断角色1
---@param targetTwo ServerPlayer | Player @ 待判断角色2
function GameMode:friendEnemyJudge (targetOne, targetTwo)
  if targetOne == targetTwo then return true end
  if targetOne.role == "civilian" or targetTwo.role == "civilian" then return true end
  if table.contains({"lord", "loyalist"}, targetOne.role) and
    table.contains({"lord", "loyalist"}, targetTwo.role) then
    return true
  end
  if table.contains({"rebel", "rebel_chief"}, targetOne.role) and
    table.contains({"rebel", "rebel_chief"}, targetTwo.role) then
    return true
  end
  return targetOne.role == targetTwo.role
end

return GameMode

