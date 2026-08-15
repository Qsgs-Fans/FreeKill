-- SPDX-License-Identifier: GPL-3.0-or-later

local basePackage = require "core.package"

--- Package用来描述一个FreeKill拓展包。
---
--- 所谓拓展包，就是武将/卡牌/游戏模式的一个集合而已。
---
---@class Package : Base.Package
---@field public type PackageType @ 拓展包的类别，只会影响到选择拓展包的界面
---@field public generals General[] @ 拓展包包含的所有武将的列表
---@field public extra_skills Skill[] @ 拓展包包含的额外技能，即不属于武将的技能
---@field public related_skills table<string, string> @ 对于额外技能而言的关联技能
---@field public cards Card[] @ 拓展包包含的卡牌
---@field public game_modes GameMode[] @ 拓展包包含的游戏模式
---@field public game_modes_whitelist? string[] @ 拓展包关于游戏模式的白名单
---@field public game_modes_blacklist? string[] @ 拓展包关于游戏模式的黑名单
---@field public skill_skels SkillSkeleton[]
---@field public card_skels CardSkeleton[]
---@field public card_specs [string, integer, integer, table][]
---@field public skin_specs table<string, SkinContent[]>
local Package = basePackage:subclass("Package")

---@alias PackageType integer

Package.GeneralPack = 1
Package.CardPack = 2
Package.SpecialPack = 3
Package.UIPack = 4
Package.SkinPack = 5

--- 拓展包的构造函数。
---@param name string @ 包的名字
---@param _type? integer @ 包的类型，默认为武将包
function Package:initialize(name, _type)
  basePackage.initialize(self, name)
  assert(type(_type) == "nil" or type(_type) == "number")
  self.type = _type or Package.GeneralPack

  self.generals = {}
  self.extra_skills = {}
  self.related_skills = {}
  self.cards = {}
  self.game_modes = {}
  self.skill_skels = {}
  self.card_skels = {}
  self.card_specs = {}
  self.skin_specs = {}
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

---@param skels SkillSkeleton[]
function Package:loadSkillSkels(skels)
  for _, e in ipairs(skels) do
    if type(e) == "table" then
      table.insert(self.skill_skels, e)
    end
  end
end

---@param path string
function Package:loadSkillSkelsByPath(path)
  local skels = {}
  local normalized_dir = path
      :gsub("^%.+/", "")
      :gsub("/+$", "")
      :gsub("/", ".")
  for _, filename in ipairs(FileIO.ls(path)) do
    if filename:sub(-4) == ".lua" and filename ~= "init.lua" then
      local skel = Pcall(require, normalized_dir .. "." .. filename:sub(1, -5))
      if skel then
        skel.file_path = path .. "/" .. filename
        table.insert(skels, skel)
      end
    end
  end
  self:loadSkillSkels(skels)
end

---@param skels CardSkeleton[]
function Package:loadCardSkels(skels)
  for _, e in ipairs(skels) do
    if type(e) == "table" then
      table.insert(self.card_skels, e)
    end
  end
end

--- 向拓展包中添加卡牌（新方法）。
---
--- 这样加入的牌之后会被clone并加入包中。
---@param name string @ 牌名
---@param suit? Suit @ 花色
---@param number? integer @ 点数
---@param extra_data? table @ 额外数据
function Package:addCardSpec(name, suit, number, extra_data)
  table.insert(self.card_specs, { name, suit, number, extra_data })
end

--- 向engine中加载一个自己。
---
--- 会加载这个自己含有的所有武将、卡牌以及游戏模式。
---@param engine Engine
function Package:install(engine)
  if engine.packages[self.name] ~= nil then
    error(string.format("Duplicate package %s detected", self.name))
  end
  engine.packages[self.name] = self
  table.insert(engine.package_names, self.name)

  -- create skills from skel
  for _, skel in ipairs(self.skill_skels) do
    local skill = skel:createSkill()
    skill.package = self
    table.insert(self.related_skills, skill)
    engine.skill_skels[skel.name] = skel
    for _, s in ipairs(skill.related_skills) do
      s.package = self
    end
    for _, sk in ipairs(skel:createAuxSkills()) do
      sk.package = self
      table.insert(self.related_skills, sk)
    end
  end

  if self.type == Package.GeneralPack then
    engine:addGenerals(self.generals)
  end
  engine:addSkills(self:getSkills())
  engine:addGameModes(self.game_modes)

  for g, skins in pairs(self.skin_specs) do
    if not engine.skin_packages[g] then engine.skin_packages[g] = {} end
    for name, skin in pairs(skins) do
      if engine.skin_packages[g][name] then
        fk.qWarning("Warning: duplicated skin name: " .. skin .. "between two extensions. general: " .. g)
      end
      engine.skin_packages[g][name] = skin
    end
  end
end

-- 加载所有皮肤拓展
---@param skinPak SkinPackageSpec
function Package:addSkinPackage(skinPak)
  skinPak.path = skinPak.path or "/image/skins"
  local pkg_path = "packages/" .. self.extensionName .. skinPak.path .. "/"
  if skinPak.url then
    pkg_path = skinPak.url
  end
  for _, arr in ipairs(skinPak.content) do
    for _, g in ipairs(arr.enabled_generals) do
      if g ~= "" then
        self.skin_specs[g] = self.skin_specs[g] or {}
        for _, skin in ipairs(arr.skins) do
          local skin_content = { name = skin, path = pkg_path } ---@type SkinContent
          if self.skin_specs[g][skin] then
            fk.qWarning("Warning: duplicated skin name: " .. skin .. " in extension " .. self.extensionName .. ". general: " .. g)
          end
          self.skin_specs[g][skin] = skin_content
        end
      end
    end
  end
end

return Package
