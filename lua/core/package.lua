-- SPDX-License-Identifier: GPL-3.0-or-later

--- Package用来描述一个FreeKill拓展包。
---
--- 所谓拓展包，就是武将/卡牌/游戏模式的一个集合而已。
---
---@class Package : Object
---@field public name string @ 拓展包的名字
---@field public extensionName string @ 拓展包对应的mod的名字。 `详情... <extension name_>`_
---@field public type PackageType @ 拓展包的类别，只会影响到选择拓展包的界面
---@field public generals General[] @ 拓展包包含的所有武将的列表
---@field public extra_skills Skill[] @ 拓展包包含的额外技能，即不属于武将的技能
---@field public related_skills table<string, string> @ 对于额外技能而言的关联技能
---@field public cards Card[] @ 拓展包包含的卡牌
---@field public game_modes GameMode[] @ 拓展包包含的游戏模式
---@field public game_modes_whitelist string[]|nil @ 拓展包关于游戏模式的白名单
---@field public game_modes_blacklist string[]|nil @ 拓展包关于游戏模式的黑名单
local Package = class("Package")

---@alias PackageType integer

Package.GeneralPack = 1
Package.CardPack = 2
Package.SpecialPack = 3

--- 拓展包的构造函数。
---@param name string @ 包的名字
---@param _type integer|nil @ 包的类型，默认为武将包
function Package:initialize(name, _type)
  assert(type(name) == "string")
  assert(type(_type) == "nil" or type(_type) == "number")
  self.name = name
  self.extensionName = name -- used for get assets
  self.type = _type or Package.GeneralPack

  self.generals = {}
  self.extra_skills = {}  -- skill not belongs to any generals, like "jixi"
  self.related_skills = {}
  self.cards = {}
  self.game_modes = {}
end

--- 获得这个包涉及的所有技能。
---
--- 这也就是说，所有的武将技能再加上和武将无关的技能。
---@return Skill[]
function Package:getSkills()
  local ret = {table.unpack(self.related_skills)}
  if self.type == Package.GeneralPack then
    for _, g in ipairs(self.generals) do
      for _, s in ipairs(g.skills) do
        table.insert(ret, s)
      end
    end
  end
  return ret
end

--- 向拓展包中添加武将。
---@param general General @ 要添加的武将
function Package:addGeneral(general)
  assert(general.class and general:isInstanceOf(General))
  table.insertIfNeed(self.generals, general)
end

--- 向拓展包中添加卡牌。
---@param card Card @ 要添加的卡牌
function Package:addCard(card)
  assert(card.class and card:isInstanceOf(Card))
  card.package = self
  table.insert(self.cards, card)
end

--- 向拓展包中一次添加许多牌。
---@param cards Card[] @ 要添加的卡牌的数组
function Package:addCards(cards)
  for _, card in ipairs(cards) do
    self:addCard(card)
  end
end

--- 向拓展包中添加游戏模式。
---@param game_mode GameMode @ 要添加的游戏模式。
function Package:addGameMode(game_mode)
  table.insert(self.game_modes, game_mode)
end

--- 向拓展包中设置游戏模式过滤。
---@param whitelist string[] @ 白名单
---@param blacklist string[] @ 黑名单
function Package:setGameModeFilter(whitelist, blacklist)
  self.game_modes_whitelist = whitelist
  self.game_modes_blacklist = blacklist
end

--- 向拓展包中添加游戏模式过滤。
---@param whitelist string[] @ 白名单
---@param blacklist string[] @ 黑名单
function Package:addGameModeFilter(whitelist, blacklist)
  assert(type(whitelist) == "table")
  assert(type(blacklist) == "table")
  table.insertTable(self.game_modes_whitelist, whitelist)
  table.insertTable(self.game_modes_blacklist, blacklist)
end
return Package
