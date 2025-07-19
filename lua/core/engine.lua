-- SPDX-License-Identifier: GPL-3.0-or-later

--@field public legacy_global_trigger LegacyTriggerSkill[] @ 所有的全局触发技
--- Engine是整个FreeKill赖以运行的核心。
---
--- 它包含了FreeKill涉及的所有武将、卡牌、游戏模式等等
---
--- 同时也提供了许多常用的函数。
---
---@class Engine : Object
---@field public extensions table<string, string[]> @ 所有mod列表及其包含的拓展包
---@field public extension_names string[] @ Mod名字的数组，为了方便排序
---@field public packages table<string, Package> @ 所有拓展包的列表
---@field public package_names string[] @ 含所有拓展包名字的数组，为了方便排序
---@field public skills table<string, Skill> @ 所有的技能
---@field public skill_skels table<string, SkillSkeleton> @ 所有的SkillSkeleton
---@field public related_skills table<string, Skill[]> @ 所有技能的关联技能
---@field public global_trigger TriggerSkill[] @ 所有的全局触发技
---@field public global_status_skill table<class, Skill[]> @ 所有的全局状态技
---@field public generals table<string, General> @ 所有武将
---@field public same_generals table<string, string[]> @ 所有同名武将组合
---@field public lords string[] @ 所有主公武将，用于常备主公
---@field public all_card_types table<string, Card> @ 所有的卡牌类型以及一张样板牌
---@field public all_card_names string[] @ 有序的所有的卡牌牌名，顺序：基本牌（杀置顶），普通锦囊，延时锦囊，按副类别排序的装备
---@field public cards Card[] @ 所有卡牌
---@field public translations table<string, table<string, string>> @ 翻译表
---@field public game_modes table<string, GameMode> @ 所有游戏模式
---@field public game_mode_disabled table<string, string[]> @ 游戏模式禁用的包
---@field public main_mode_list table<string, string[]> @ 主模式检索表
---@field public currentResponsePattern string @ 要求用牌的种类（如要求用特定花色的桃···）
---@field public currentResponseReason string @ 要求用牌的原因（如濒死，被特定牌指定，使用特定技能···）
---@field public filtered_cards table<integer, Card> @ 被锁视技影响的卡牌
---@field public printed_cards table<integer, Card> @ 被某些房间现场打印的卡牌，id都是负数且从-2开始
---@field private kingdoms string[] @ 总势力
---@field private kingdom_map table<string, string[]> @ 势力映射表
---@field private damage_nature table<any, [string, boolean]> @ 伤害映射表
---@field private _custom_events any[] @ 自定义事件列表
---@field public poxi_methods table<string, PoxiSpec> @ “魄袭”框操作方法表
---@field public qml_marks table<string, QmlMarkSpec> @ 自定义Qml标记的表
---@field public mini_games table<string, MiniGameSpec> @ 自定义多人交互表
---@field public request_handlers table<string, RequestHandler> @ 请求处理程序
---@field public target_tips table<string, TargetTipSpec> @ 选择目标提示对应表
---@field public choose_general_rule table<string, ChooseGeneralSpec> @ 选将框操作方法表
local Engine = class("Engine")

--- Engine的构造函数。
---
--- 这个函数只应该被执行一次。执行了之后，会创建一个Engine实例，并放入全局变量Fk中。
---@return nil
function Engine:initialize()
  -- Engine should be singleton
  if Fk ~= nil then
    error("Engine has been initialized")
    return
  end

  Fk = self
  self.extensions = {
    ["standard"] = { "standard" },
    ["standard_cards"] = { "standard_cards" },
    ["maneuvering"] = { "maneuvering" },
    ["test"] = { "test_p_0" },
  }
  self.extension_names = { "standard", "standard_cards", "maneuvering", "test" }
  self.packages = {}    -- name --> Package
  self.package_names = {}
  self.skill_keys = {    -- key --> {SkillSkeleton.createSkill, integer}
    ["distance"] = {SkillSkeleton.createDistanceSkill, 1},
    ["prohibit"] = {SkillSkeleton.createProhibitSkill, 1},
    ["atkrange"] = {SkillSkeleton.createAttackRangeSkill, 1},
    ["maxcards"] = {SkillSkeleton.createMaxCardsSkill, 1},
    ["targetmod"] = {SkillSkeleton.createTargetModSkill, 1},
    ["filter"] = {SkillSkeleton.createFilterSkill, 1},
    ["invalidity"] = {SkillSkeleton.createInvaliditySkill, 1},
    ["visibility"] = {SkillSkeleton.createVisibilitySkill, 1},
    ["active"] = {SkillSkeleton.createActiveSkill, 5},
    ["cardskill"] = {SkillSkeleton.createCardSkill, 5},
    ["viewas"] = {SkillSkeleton.createViewAsSkill, 5},
  }
  self.skills = {}    -- name --> Skill
  self.skill_skels = {}    -- name --> SkillSkeleton
  self.related_skills = {} -- skillName --> relatedSkill[]
  self.global_trigger = {}
  self.legacy_global_trigger = {}
  self.global_status_skill = {}
  self.generals = {}    -- name --> General
  self.same_generals = {}
  self.lords = {}     -- lordName[]
  self.all_card_types = {}
  self.all_card_names = {}
  self.cards = {}     -- Card[]
  self.translations = {}  -- srcText --> translated
  self.game_modes = {}
  self.game_mode_disabled = {}
  self.main_mode_list = {}
  self.kingdoms = {}
  self.kingdom_map = {}
  self.damage_nature = { [fk.NormalDamage] = { "normal_damage", false } }
  self._custom_events = {}
  self.poxi_methods = {}
  self.qml_marks = {}
  self.mini_games = {}
  self.request_handlers = {}
  self.target_tips = {}
  self.choose_general_rule = {}

  self:loadPackages()
  self:setLords()
  self:loadCardNames()
  self:loadDisabled()
  self:loadRequestHandlers()
end

local _foreign_keys = {
  ["currentResponsePattern"] = true,
  ["currentResponseReason"] = true,
  ["filtered_cards"] = true,
  ["printed_cards"] = true,
}

function Engine:__index(k)
  if _foreign_keys[k] then
    return self:currentRoom()[k]
  end
end

function Engine:__newindex(k, v)
  if _foreign_keys[k] then
    self:currentRoom()[k] = v
  else
    rawset(self, k, v)
  end
end

--- 向Engine中加载一个拓展包。
---
--- 会加载这个拓展包含有的所有武将、卡牌以及游戏模式。
---@param pack Package @ 要加载的拓展包
function Engine:loadPackage(pack)
  assert(pack:isInstanceOf(Package))
  if self.packages[pack.name] ~= nil then
    error(string.format("Duplicate package %s detected", pack.name))
  end
  self.packages[pack.name] = pack
  table.insert(self.package_names, pack.name)

  -- create skills from skel
  for _, skel in ipairs(pack.skill_skels) do
    local skill = skel:createSkill()
    skill.package = pack
    table.insert(pack.related_skills, skill)
    self.skill_skels[skel.name] = skel
    for _, s in ipairs(skill.related_skills) do
      s.package = pack
    end
  end

  if pack.type == Package.GeneralPack then
    self:addGenerals(pack.generals)
  end
  self:addSkills(pack:getSkills())
  self:addGameModes(pack.game_modes)
end

-- Don't do this

local package = package

function Engine:reloadPackage(path)
  ---@cast package -nil
  path = path:sub(1, #path - 4)
  local oldPkg = package.loaded[path]
  package.loaded[path] = nil
  local ok, err = pcall(require, path)
  if not ok then
    package.loaded[path] = oldPkg
    print("reload failed:", err)
    return
  end

  -- 阉割版重载机制，反正单机用
  local function replace(t, skill)
    if not t then return end
    for k, s in pairs(t) do
      if s.name == skill.name then
        t[k] = skill
        break
      end
    end
  end

  ---@param p Package
  local function f(p)
    self.packages[p.name] = p
    local room = Fk:currentRoom()
    local skills = p:getSkills()
    local related = {}
    for _, skill in ipairs(skills) do
      table.insertTableIfNeed(related, skill.related_skills)
    end
    table.insertTableIfNeed(skills, related)

    for _, skill in ipairs(skills) do
      if self.skills[skill.name].class ~= skill.class then
        fk.qCritical("cannot change class of skill: " .. skill.name)
        goto CONTINUE
      end
      self.skills[skill.name] = skill
      if skill:isInstanceOf(TriggerSkill) and RoomInstance then
        ---@cast room Room
        local logic = room.logic
        for _, event in ipairs(skill.refresh_events) do
          replace(logic.refresh_skill_table[event], skill)
        end
        for _, event in ipairs(skill.events) do
          replace(logic.skill_table[event], skill)
        end
      end
      if skill:isInstanceOf(StatusSkill) then
        replace(room.status_skills[skill.class], skill)
      end

      for _, _p in ipairs(room.players) do
        replace(_p.player_skills, skill)
      end
      ::CONTINUE::
    end
  end

  local pkg = package.loaded[path]
  if type(pkg) ~= "table" then return end
  if pkg.class and pkg:isInstanceOf(Package) then
    f(pkg)
  elseif path:endsWith("init") and not path:find("/ai/") then
    for _, p in ipairs(pkg) do f(p) end
  end
end


--- 加载所有拓展包。
---
--- Engine会在packages/下搜索所有含有init.lua的文件夹，并把它们作为拓展包加载进来。
---
--- 这样的init.lua可以返回单个拓展包，也可以返回拓展包数组，或者什么都不返回。
---
--- 标包和标准卡牌包比较特殊，它们永远会在第一个加载。
---@return nil
function Engine:loadPackages()
  if FileIO.pwd():endsWith("packages/freekill-core") then
    UsingNewCore = true
    FileIO.cd("../..")
  end
  local directories = FileIO.ls("packages")

  -- load standard & standard_cards first
  if UsingNewCore then
    self:loadPackage(require("packages.freekill-core.standard"))
    self:loadPackage(require("packages.freekill-core.standard_cards"))
    self:loadPackage(require("packages.freekill-core.maneuvering"))
    self:loadPackage(require("packages.freekill-core.test"))
    table.removeOne(directories, "freekill-core")
  else
    self:loadPackage(require("packages.standard"))
    self:loadPackage(require("packages.standard_cards"))
    self:loadPackage(require("packages.maneuvering"))
    self:loadPackage(require("packages.test"))
  end
  table.removeOne(directories, "standard")
  table.removeOne(directories, "standard_cards")
  table.removeOne(directories, "maneuvering")
  table.removeOne(directories, "test")

  ---@type string[]
  local _disable_packs = json.decode(fk.GetDisabledPacks())

  for _, dir in ipairs(directories) do
    if (not string.find(dir, ".disabled")) and not table.contains(_disable_packs, dir)
      and FileIO.isDir("packages/" .. dir)
      and FileIO.exists("packages/" .. dir .. "/init.lua") then
      local pack = Pcall(require, string.format("packages.%s", dir))
      -- Note that instance of Package is a table too
      -- so dont use type(pack) == "table" here
      if type(pack) == "table" then
        table.insert(self.extension_names, dir)
        if pack[1] ~= nil then
          self.extensions[dir] = {}
          for _, p in ipairs(pack) do
            table.insert(self.extensions[dir], p.name)
            self:loadPackage(p)
          end
        else
          self.extensions[dir] = { pack.name }
          self:loadPackage(pack)
        end
      end
    end
  end

  -- 把card放在后面加载吧
  for _, pkname in ipairs(self.package_names) do
    local pack = self.packages[pkname]

    for _, skel in ipairs(pack.card_skels) do
      local card = skel:createCardPrototype()
      if card then
        card.package = pack
        self.skills[card.skill.name] = self.skills[card.skill.name] or card.skill
        self.all_card_types[card.name] = card
        table.insert(self.all_card_names, card.name)
      end
    end

    for _, tab in ipairs(pack.card_specs) do
      local card = self:cloneCard(tab[1], tab[2], tab[3])
      card.extra_data = tab[4]
      pack:addCard(card)
    end

    -- add cards, generals and skills to Engine
    if pack.type == Package.CardPack then
      self:addCards(pack.cards)
    end
  end

  if UsingNewCore then
    FileIO.cd("packages/freekill-core")
  end
end

---@return nil
function Engine:loadDisabled()
  for mode_name, game_mode in pairs(self.game_modes) do
    local disabled_packages = {}
    for name, pkg in pairs(self.packages) do
      --- GameMode对Package筛选
      local wl = game_mode.whitelist
      local bl = game_mode.blacklist
      if type(wl) == "function" then
        if not wl(game_mode, pkg) then
          table.insert(disabled_packages, name)
        end
      elseif type(wl) == "table" then
        ---@cast wl string[]
        if not table.contains(wl, name) then
          table.insert(disabled_packages, name)
        end
      end
      if type(bl) == "function" then
        if bl(game_mode, pkg) then
          table.insert(disabled_packages, name)
        end
      elseif type(bl) == "table" then
        ---@cast bl string[]
        if table.contains(bl, name) then
          table.insert(disabled_packages, name)
        end
      end

      --- Package对GameMode筛选
      if table.contains(pkg.game_modes_blacklist or Util.DummyTable, mode_name) or
      (pkg.game_modes_whitelist and not table.contains(pkg.game_modes_whitelist, mode_name)) then
        table.insert(disabled_packages, name)
      end
    end
    self.game_mode_disabled[game_mode.name] = disabled_packages
  end
end

--- 载入响应事件
function Engine:loadRequestHandlers()
  self.request_handlers["AskForSkillInvoke"] = require 'core.request_type.invoke'
  self.request_handlers["AskForUseActiveSkill"] = require 'core.request_type.active_skill'
  self.request_handlers["AskForResponseCard"] = require 'core.request_type.response_card'
  self.request_handlers["AskForUseCard"] = require 'core.request_type.use_card'
  self.request_handlers["PlayCard"] = require 'core.request_type.play_card'
end

--- 向翻译表中加载新的翻译表。
---@param t table @ 要加载的翻译表，这是一个 原文 --> 译文 的键值对表
---@param lang? string @ 目标语言，默认为zh_CN
function Engine:loadTranslationTable(t, lang)
  assert(type(t) == "table")
  lang = lang or "zh_CN"
  self.translations[lang] = self.translations[lang] or {}
  for k, v in pairs(t) do
    self.translations[lang][k] = v
  end
end

--- 翻译一段文本。其实就是从翻译表中去找
---@param src string @ 要翻译的文本
---@param lang? string @ 要使用的语言，默认读取config
function Engine:translate(src, lang)
  lang = lang or (Config.language or "zh_CN")
  if not self.translations[lang] then lang = "zh_CN" end
  local ret = self.translations[lang][src]
  return ret or src
end

--- 向Engine中加载一个技能。
---
--- 如果技能是global的，那么同时会将其放到那些global技能表中。
---
--- 如果技能有关联技能，那么递归地加载那些关联技能。
---@param skill Skill @ 要加载的技能
function Engine:addSkill(skill)
  assert(skill:isInstanceOf(Skill))
  if self.skills[skill.name] ~= nil then
    local old = self.skills[skill.name]
    fk.qWarning(string.format("Duplicate skill %s detected[package exist %s, new package %s ]",
    skill.name,
    old.package and old.package.name or "unknown_pack",
    skill.package and skill.package.name or "unknown_pack"))
  end
  self.skills[skill.name] = skill

  for _, sk in ipairs{ skill, table.unpack(skill.related_skills) } do
    if sk.global then
      if sk:isInstanceOf(TriggerSkill) then
        table.insertIfNeed(self.global_trigger, sk)
      -- elseif sk:isInstanceOf(LegacyTriggerSkill) then
      --   table.insertIfNeed(self.legacy_global_trigger, sk)
      else
        local t = self.global_status_skill
        t[sk.class] = t[sk.class] or {}
        table.insertIfNeed(t[sk.class], sk)
      end
    end
  end

  for _, s in ipairs(skill.related_skills) do
    self:addSkill(s)
  end
end

--- 加载一系列技能。
---@param skills Skill[] @ 要加载的技能数组
function Engine:addSkills(skills)
  assert(type(skills) == "table")
  for _, skill in ipairs(skills) do
    self:addSkill(skill)
  end
end

--- 注册技能（effect）类型
---@param key string @ 技能类型名
---@param func function @ 技能类型创建函数
---@param priority integer? @ 优先级，默认为1
function Engine:addSkillType(key, func, priority)
  self.skill_keys[key] = {func, priority or 1}
end

--- 加载一个武将到Engine中。
---
--- 如果武将的trueName和name不同的话，那么也会将其加到同将清单中。
---@param general General @ 要添加的武将
function Engine:addGeneral(general)
  assert(general:isInstanceOf(General))
  if self.generals[general.name] ~= nil then
    local old = self.generals[general.name]
    error(string.format("Duplicate general %s detected[package exist %s, new package %s ]",
    general.name,
    old.package and old.package.name or "unknown_pack",
    general.package and general.package.name or "unknown_pack"
    ))
  end
  self.generals[general.name] = general

  if general.kingdom ~= "unknown" then
    table.insertIfNeed(self.kingdoms, general.kingdom)
  end

  if general.name ~= general.trueName then
    local tName = general.trueName
    self.same_generals[tName] = self.same_generals[tName] or { tName }
    table.insert(self.same_generals[tName], general.name)
  end
end

--- 加载一系列武将。
---@param generals General[] @ 要加载的武将列表
function Engine:addGenerals(generals)
  assert(type(generals) == "table")
  for _, general in ipairs(generals) do
    self:addGeneral(general)
  end
end

--- 为所有武将加载主公技和主公判定
function Engine:setLords()
  for _, general in pairs(self.generals) do
    local other_skills = table.map(general.other_skills, Util.Name2SkillMapper)
    local skills = table.connect(general.skills, other_skills)
    for _, skill in ipairs(skills) do
      if skill:hasTag(Skill.Lord) then
        table.insert(self.lords, general.name)
        break
      end
    end
  end
end

--- 为一个势力添加势力映射
---
--- 这意味着原势力登场时必须改变为添加的几个势力之一(须存在)
---@param kingdom string @ 原势力
---@param kingdoms string[] @ 需要映射到的势力
function Engine:appendKingdomMap(kingdom, kingdoms)
  local ret = self.kingdom_map[kingdom] or {}
  table.insertTableIfNeed(ret, kingdoms)
  self.kingdom_map[kingdom] = ret
end

---获得一个势力所映射到的势力，若没有，返回空集
---@param kingdom string @ 原势力
---@return string[] @ 可用势力列表，可能是空的
function Engine:getKingdomMap(kingdom)
  local ret = {}
  for _, k in ipairs(self.kingdom_map[kingdom] or {}) do
    if table.contains(self.kingdoms, k) then
      table.insertIfNeed(ret, k)
    end
  end
  return ret
end

--- 注册一个伤害
---@param nature string | number @ 伤害ID
---@param name string @ 属性伤害名
---@param can_chain boolean? @ 是否可传导，默认可
function Engine:addDamageNature(nature, name, can_chain)
  assert(table.contains({ "string", "number" }, type(nature)), "Must use string or number as nature!")
  assert(type(name) == "string", "Must use string as this damage nature's name!")
  if can_chain == nil then can_chain = true end
  self.damage_nature[nature] = { name, can_chain }
end

--- 返回伤害列表
---@return table<any, [string, boolean]> @ 具体信息（伤害ID => {伤害名，是否可传导}）
function Engine:getDamageNatures()
  return table.simpleClone(self.damage_nature)
end

--- 由伤害ID获得伤害属性
---@param nature string | number @ 伤害ID
---@return table @ 具体信息（{伤害名，是否可传导}），若不存在则为空
function Engine:getDamageNature(nature)
  return self.damage_nature[nature]
end

--- 由伤害ID获得伤害名
---@param nature string | number @ 伤害ID
---@return string @ 伤害名
function Engine:getDamageNatureName(nature)
  local ret = self:getDamageNature(nature)
  return ret and ret[1] or ""
end

--- 判断一种伤害是否可传导
---@param nature string | number @ 伤害ID
---@return boolean?
function Engine:canChain(nature)
  local ret = self:getDamageNature(nature)
  return ret and ret[2]
end

--- 判断一个武将是否在本房间可用。
---@param g string @ 武将名
function Engine:canUseGeneral(g)
  local r = self:currentRoom()
  local general = self.generals[g]
  if not general then return false end
  return not table.contains(r.disabled_packs, general.package.name) and
    not table.contains(r.disabled_generals, g) and not general.hidden and not general.total_hidden
end

--- 根据武将名称，获取它的同名武将。
---
--- 注意以此法返回的同名武将列表不包含他自己。
---@param name string @ 要查询的武将名字
---@return string[] @ 这个武将对应的同名武将列表
function Engine:getSameGenerals(name)
  if not self.generals[name] then return {} end
  local tName = self.generals[name].trueName
  local ret = self.same_generals[tName] or {}
  return table.filter(ret, function(g)
    return g ~= name and self.generals[g] ~= nil and self:canUseGeneral(g)
  end)
end

local cardId = 1

--- 向Engine中加载一张卡牌。
---
--- 卡牌在加载的时候，会被赋予一个唯一的id。（从1开始）
---@param card Card @ 要加载的卡牌
function Engine:addCard(card)
  assert(card.class:isSubclassOf(Card))
  card.id = cardId
  cardId = cardId + 1
  table.insert(self.cards, card)
  if self.all_card_types[card.name] == nil then
    self.skills[card.skill.name] = card.skill
    self.all_card_types[card.name] = card
    table.insert(self.all_card_names, card.name)
  end
end

--- 向Engine中加载一系列卡牌。
---@param cards Card[] @ 要加载的卡牌列表
function Engine:addCards(cards)
  for _, card in ipairs(cards) do
    self:addCard(card)
  end
end

--- 根据牌名、花色、点数，复制一张牌。
---
--- 返回的牌是一张虚拟牌。
---@param name string @ 牌名
---@param suit? Suit @ 花色
---@param number? integer @ 点数
---@return Card
function Engine:cloneCard(name, suit, number)
  local cd = self.all_card_types[name]
  assert(cd, string.format("Attempt to clone a card that not added to engine: name=%s", name))
  local ret = cd:clone(suit, number)
  ret.package = cd.package
  return ret
end

--- 为所有加载的卡牌牌名排序
function Engine:loadCardNames()
  local slash, basic, commonTrick, other = {}, {}, {}, {}
  for _, name in ipairs(self.all_card_names) do
    local card = self.all_card_types[name]
    if card.type == Card.TypeBasic then
      table.insert(card.trueName == "slash" and slash or basic, name)
    elseif card:isCommonTrick() then
      table.insert(commonTrick, name)
    else
      table.insert(other, name)
    end
  end
  table.sort(other, function(a, b) return self.all_card_types[a].sub_type < self.all_card_types[b].sub_type end)
  self.all_card_names = table.connect(slash, basic, commonTrick, other)
end

--- 向Engine中添加一系列游戏模式。
---@param game_modes GameMode[] @ 要添加的游戏模式列表
function Engine:addGameModes(game_modes)
  for _, s in ipairs(game_modes) do
    self:addGameMode(s)
  end
end

--- 向Engine中添加一个游戏模式。
---@param game_mode GameMode @ 要添加的游戏模式
function Engine:addGameMode(game_mode)
  assert(game_mode:isInstanceOf(GameMode))
  if self.game_modes[game_mode.name] ~= nil then
    error(string.format("Duplicate game_mode %s detected", game_mode.name))
  end
  self.game_modes[game_mode.name] = game_mode
end

--- 向Engine中添加一个自定义事件。
---@param name string @ 名称
---@param pfunc? function @ prepare function
---@param mfunc function @ (main) function
---@param cfunc? function @ cleaner function
---@param efunc? function @ exit function
function Engine:addGameEvent(name, pfunc, mfunc, cfunc, efunc)
  table.insert(self._custom_events, { name = name, p = pfunc, m = mfunc, c = cfunc, e = efunc })
end

---@param spec PoxiSpec
function Engine:addPoxiMethod(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.card_filter) == "function")
  assert(type(spec.feasible) == "function")
  if self.poxi_methods[spec.name] then
    fk.qCritical("Warning: duplicated poxi_method " .. spec.name)
  end
  self.poxi_methods[spec.name] = spec
  spec.default_choice = spec.default_choice or function() return {} end
  spec.post_select = spec.post_select or function(s) return s end
end

---@param spec QmlMarkSpec
function Engine:addQmlMark(spec)
  assert(type(spec.name) == "string")
  if self.qml_marks[spec.name] then
    fk.qCritical("Warning: duplicated qml mark type " .. spec.name)
  end
  self.qml_marks[spec.name] = spec
end

---@param spec MiniGameSpec
function Engine:addMiniGame(spec)
  assert(type(spec.name) == "string")
  if self.mini_games[spec.name] then
    fk.qCritical("Warning: duplicated mini game type " .. spec.name)
  end
  self.mini_games[spec.name] = spec
end

---@param spec TargetTipSpec
function Engine:addTargetTip(spec)
  assert(type(spec.name) == "string")
  if self.target_tips[spec.name] then
    fk.qCritical("Warning: duplicated target tip type " .. spec.name)
  end
  self.target_tips[spec.name] = spec
end

---@param spec ChooseGeneralSpec
function Engine:addChooseGeneralRule(spec)
  assert(type(spec.name) == "string")
  assert(type(spec.card_filter) == "function")
  assert(type(spec.feasible) == "function")
  if self.choose_general_rule[spec.name] then
    fk.qCritical("Warning: duplicated choose_general_rule " .. spec.name)
  end
  self.choose_general_rule[spec.name] = spec
  --spec.card_filter = spec.card_filter or function() return {} end
  --spec.feasible = spec.feasible or Util.TrueFunc
  spec.default_choice = spec.default_choice or function() return {} end
end

--- 从已经开启的拓展包中，随机选出若干名武将。
---
--- 对于同名武将不会重复选取。
---
--- 如果符合条件的武将不够，那么就不能保证能选出那么多武将。
---@param num integer @ 要选出的武将数量
---@param generalPool? General[] @ 选择的范围，默认是已经启用的所有武将
---@param except? string[] @ 特别要排除掉的武将名列表，默认是空表
---@param filter? fun(g: General): boolean? @ 可选参数，若这个函数返回true的话这个武将被排除在外
---@return General[] @ 随机选出的武将列表
function Engine:getGeneralsRandomly(num, generalPool, except, filter)
  if filter then
    assert(type(filter) == "function")
  end

  generalPool = generalPool or self:getAllGenerals()
  except = except or {}
  for _, g in ipairs(self.packages["test_p_0"].generals) do
    table.insert(except, g.name)
  end

  local availableGenerals = {}
  for _, general in pairs(generalPool) do
    if not table.contains(except, general.name) and not (filter and filter(general)) then
      if (not general.hidden and not general.total_hidden) and
        #table.filter(availableGenerals, function(g)
        return g.trueName == general.trueName
      end) == 0 then
        table.insert(availableGenerals, general)
      end
    end
  end

  if #availableGenerals < num then
    return {}
  end

  return table.random(availableGenerals, num)
end

--- 获取已经启用的所有武将的列表。
---@param except? General[] @ 特别指明要排除在外的武将
---@return General[] @ 所有武将的列表
function Engine:getAllGenerals(except)
  local result = {}
  for _, general in pairs(self.generals) do
    if not (except and table.contains(except, general)) then
      if self:canUseGeneral(general.name) then
        table.insert(result, general)
      end
    end
  end

  return result
end

--- 获取当前已经启用的所有卡牌。
---@param except? integer[] @ 特别指定要排除在外的id列表
---@return integer[] @ 所有卡牌id的列表
function Engine:getAllCardIds(except)
  local result = {}
  for _, card in ipairs(self.cards) do
    if card.package and not (except and table.contains(except, card.id)) then
      if not table.contains(self:currentRoom().disabled_packs, card.package.name) then
        table.insert(result, card.id)
      end
    end
  end

  return result
end

-- 获取加入游戏的卡的牌名（暂不考虑装备牌），常用于泛转化技能的interaction
---@param card_type string @ 卡牌的类别，b 基本牌，t - 普通锦囊牌，d - 延时锦囊牌，e - 装备牌
---@param true_name? boolean @ 是否使用真实卡名（即不区分【杀】、【无懈可击】等的具体种类）
---@param is_derived? boolean @ 是否包括衍生牌，默认不包括
---@return string[] @ 返回牌名列表
function Engine:getAllCardNames(card_type, true_name, is_derived)
  local all_names = {}
  local basic, equip, normal_trick, delayed_trick = {}, {}, {}, {}
  for _, card in ipairs(self.cards) do
    if not table.contains(self:currentRoom().disabled_packs, card.package.name) and (not card.is_derived or is_derived) then
      if card.type == Card.TypeBasic then
        table.insertIfNeed(basic, true_name and card.trueName or card.name)
      elseif card.type == Card.TypeEquip then
        table.insertIfNeed(equip, true_name and card.trueName or card.name)
      elseif card.sub_type ~= Card.SubtypeDelayedTrick then
        table.insertIfNeed(normal_trick, true_name and card.trueName or card.name)
      else
        table.insertIfNeed(delayed_trick, true_name and card.trueName or card.name)
      end
    end
  end
  if card_type:find("b") then
    table.insertTable(all_names, basic)
  end
  if card_type:find("t") then
    table.insertTable(all_names, normal_trick)
  end
  if card_type:find("d") then
    table.insertTable(all_names, delayed_trick)
  end
  if card_type:find("e") then
    table.insertTable(all_names, equip)
  end
  return all_names
end

--- 根据id返回相应的卡牌。
---@param id integer @ 牌的id
---@param ignoreFilter? boolean @ 是否要无视掉锁定视为技，直接获得真牌
---@return Card @ 这个id对应的卡牌
function Engine:getCardById(id, ignoreFilter)
  if id == nil then return nil end
  local card_tab = (id >= -1) and self.cards or self.printed_cards
  local ret = card_tab[id]
  if not ignoreFilter then
    ret = self.filtered_cards[id] or card_tab[id]
  end
  return ret
end

--- 对那个id应用锁定视为技，将它变成要被锁定视为的牌。
---@param id integer @ 要处理的id
---@param player? Player @ 和这张牌有关的角色。若无则还原为原卡牌
function Engine:filterCard(id, player)
  if player == nil then
    self.filtered_cards[id] = nil
    return
  end

  local card = Fk:getCardById(id, true)
  local filters = Fk:currentRoom().status_skills[FilterSkill] or Util.DummyTable---@type FilterSkill[]

  if #filters == 0 then
    self.filtered_cards[id] = nil
    return
  end

  local modity = false
  for _, f in ipairs(filters) do
    if f:cardFilter(card, player) then
      local new_card = f:viewAs(player, card)
      if new_card then
        new_card.id = id
        new_card.skillName = f.name
        card = new_card
        self.filtered_cards[id] = card
        modity = true
      end
    end
  end
  if not modity then
    self.filtered_cards[id] = nil
  end
end

--- 获知当前的Engine是跑在服务端还是客户端，并返回相应的实例。
---@return AbstractRoom
function Engine:currentRoom()
  if RoomInstance then
    return RoomInstance
  end
  return ClientInstance
end

---@param name string @ 要获得描述的名字
---@param lang? string @ 要使用的语言，默认读取config
---@param player Player @ 绑定角色，用于获取技能的动态描述
---@param with_effectable? boolean @ 是否需要加上无效红字显示
---@return string @ 描述
function Engine:getSkillName(name, lang, player, with_effectable)
  lang = lang or (Config.language or "zh_CN")
  local skill = Fk.skills[name]
  local _name
  if skill.skeleton then -- 新框架
    _name = skill.skeleton:getDynamicName(player, lang)
  end
  if type(_name) == "string" and _name ~= "" then
    _name = self:translate(_name, lang)
  else
    _name = self:translate(name, lang)
  end
  if with_effectable then
    return _name .. (skill:isEffectable(player) and "" or self:translate("skill_invalidity", lang)) -- 无效显示
  else
    return _name
  end
end

--- 根据字符串获得这个技能或者这张牌的（动态）描述
---@param name string @ 要获得描述的名字
---@param lang? string @ 要使用的语言，默认读取config
---@param player? Player @ 绑定角色，用于获取技能的动态描述
---@return string @ 描述
function Engine:getDescription(name, lang, player)
  local skill = Fk.skills[name]
  if player and skill then
    local dynamicDesc
    if skill.skeleton then
      dynamicDesc = skill.skeleton:getDynamicDescription(player, lang)
    end
    if type(dynamicDesc) ~= "string" or dynamicDesc == "" then
      dynamicDesc = skill:getDynamicDescription(player, lang)
    end
    if type(dynamicDesc) == "string" and dynamicDesc ~= "" then
      local descFormatter = function(desc)
        local descSplit = desc:split(":")
        local descFormatted = self:translate(":" .. descSplit[1], lang)
        if descFormatted ~= ":" .. descSplit[1] then
          for i = 2, #descSplit do
            local curDesc = self:translate(descSplit[i], lang)
            descFormatted = descFormatted:gsub("{" .. (i - 1) .. "}", curDesc)
          end

          return descFormatted
        end

        return desc
      end

      return descFormatter(dynamicDesc)
    end
  end

  return self:translate(":" .. name, lang)
end

return Engine
