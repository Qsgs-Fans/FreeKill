-- SPDX-License-Identifier: GPL-3.0-or-later

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
---@field public related_skills table<string, Skill[]> @ 所有技能的关联技能
---@field public global_trigger TriggerSkill[] @ 所有的全局触发技
---@field public global_status_skill table<class, Skill[]> @ 所有的全局状态技
---@field public generals table<string, General> @ 所有武将
---@field public same_generals table<string, string[]> @ 所有同名武将组合
---@field public lords string[] @ 所有主公武将，用于常备主公
---@field public all_card_types table<string, Card> @ 所有的卡牌类型以及一张样板牌
---@field public cards Card[] @ 所有卡牌
---@field public translations table<string, table<string, string>> @ 翻译表
---@field public game_modes table<string, GameMode> @ 所有游戏模式
---@field public game_mode_disabled table<string, string[]> @ 游戏模式禁用的包
---@field public currentResponsePattern string @ 要求用牌的种类（如要求用特定花色的桃···）
---@field public currentResponseReason string @ 要求用牌的原因（如濒死，被特定牌指定，使用特定技能···）
---@field public filtered_cards table<integer, Card> @ 被锁视技影响的卡牌
---@field public printed_cards table<integer, Card> @ 被某些房间现场打印的卡牌，id都是负数且从-2开始
---@field private kingdoms string[] @ 总势力
---@field private kingdom_map table<string, string[]> @ 势力映射表
---@field private _custom_events any[] @ 自定义事件列表
---@field public poxi_methods table<string, PoxiSpec> @ “魄袭”框操作方法表
---@field public qml_marks table<string, QmlMarkSpec> @ 自定义Qml标记的表
---@field public mini_games table<string, MiniGameSpec> @ 自定义多人交互表
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
  }
  self.extension_names = { "standard", "standard_cards", "maneuvering" }
  self.packages = {}    -- name --> Package
  self.package_names = {}
  self.skills = {}    -- name --> Skill
  self.related_skills = {} -- skillName --> relatedSkill[]
  self.global_trigger = {}
  self.global_status_skill = {}
  self.generals = {}    -- name --> General
  self.same_generals = {}
  self.lords = {}     -- lordName[]
  self.all_card_types = {}
  self.cards = {}     -- Card[]
  self.translations = {}  -- srcText --> translated
  self.game_modes = {}
  self.game_mode_disabled = {}
  self.kingdoms = {}
  self.kingdom_map = {}
  self._custom_events = {}
  self.poxi_methods = {}
  self.qml_marks = {}
  self.mini_games = {}

  self:loadPackages()
  self:loadDisabled()
  self:addSkills(AuxSkills)
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

  -- add cards, generals and skills to Engine
  if pack.type == Package.CardPack then
    self:addCards(pack.cards)
  elseif pack.type == Package.GeneralPack then
    self:addGenerals(pack.generals)
  end
  self:addSkills(pack:getSkills())
  self:addGameModes(pack.game_modes)
end

-- Don't do this
local package = package
function Engine:reloadPackage(path)
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

      for _, p in ipairs(room.players) do
        replace(p.player_skills, skill)
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
  local new_core = false
  if FileIO.pwd():endsWith("packages/freekill-core") then
    new_core = true
    FileIO.cd("../..")
  end
  local directories = FileIO.ls("packages")

  -- load standard & standard_cards first
  if new_core then
    self:loadPackage(require("packages.freekill-core.standard"))
    self:loadPackage(require("packages.freekill-core.standard_cards"))
    self:loadPackage(require("packages.freekill-core.maneuvering"))
    table.removeOne(directories, "freekill-core")
  else
    self:loadPackage(require("packages.standard"))
    self:loadPackage(require("packages.standard_cards"))
    self:loadPackage(require("packages.maneuvering"))
  end
  table.removeOne(directories, "standard")
  table.removeOne(directories, "standard_cards")
  table.removeOne(directories, "maneuvering")

  local _disable_packs = json.decode(fk.GetDisabledPacks())

  for _, dir in ipairs(directories) do
    if (not string.find(dir, ".disabled")) and not table.contains(_disable_packs, dir)
      and FileIO.isDir("packages/" .. dir)
      and FileIO.exists("packages/" .. dir .. "/init.lua") then
      local pack = require(string.format("packages.%s", dir))
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

  if new_core then
    FileIO.cd("packages/freekill-core")
  end
end

---@return nil
function Engine:loadDisabled()
  for mode_name, game_mode in pairs(self.game_modes) do
    local disabled_packages = {}
    for name, pkg in pairs(self.packages) do
      if table.contains(game_mode.blacklist or Util.DummyTable, name) or
      (game_mode.whitelist and not table.contains(game_mode.whitelist, name)) or
      table.contains(pkg.game_modes_blacklist or Util.DummyTable, mode_name) or
      (pkg.game_modes_whitelist and not table.contains(pkg.game_modes_whitelist, mode_name)) then
        table.insert(disabled_packages, name)
      end
    end
    self.game_mode_disabled[game_mode.name] = disabled_packages
  end
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
  assert(skill.class:isSubclassOf(Skill))
  if self.skills[skill.name] ~= nil then
    fk.qWarning(string.format("Duplicate skill %s detected", skill.name))
  end
  self.skills[skill.name] = skill

  if skill.global then
    if skill:isInstanceOf(TriggerSkill) then
      table.insert(self.global_trigger, skill)
    else
      local t = self.global_status_skill
      t[skill.class] = t[skill.class] or {}
      table.insert(t[skill.class], skill)
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

--- 加载一个武将到Engine中。
---
--- 如果武将的trueName和name不同的话，那么也会将其加到同将清单中。
---@param general General @ 要添加的武将
function Engine:addGeneral(general)
  assert(general:isInstanceOf(General))
  if self.generals[general.name] ~= nil then
    error(string.format("Duplicate general %s detected", general.name))
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

  if table.find(general.skills, function(s) return s.lordSkill end) then
    table.insert(self.lords, general.name)
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
  assert(cd, "Attempt to clone a card that not added to engine")
  local ret = cd:clone(suit, number)
  ret.package = cd.package
  return ret
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
    if not (except and table.contains(except, card.id)) then
      if not table.contains(self:currentRoom().disabled_packs, card.package.name) then
        table.insert(result, card.id)
      end
    end
  end

  return result
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
---@param player Player @ 和这张牌扯上关系的那名玩家
---@param data any @ 随意，目前只用到JudgeStruct，为了影响判定牌
function Engine:filterCard(id, player, data)
  if player == nil then
    self.filtered_cards[id] = nil
    return
  end

  local card = self:getCardById(id, true)
  local filters = self:currentRoom().status_skills[FilterSkill] or Util.DummyTable

  if #filters == 0 then
    self.filtered_cards[id] = nil
    return
  end

  local modify = false
  if data and type(data) == "table" and data.card
    and type(data.card) == "table" and data.card:isInstanceOf(Card) then
    modify = true
  end

  for _, f in ipairs(filters) do
    if f:cardFilter(card, player, type(data) == "table" and data.isJudgeEvent) then
      local _card = f:viewAs(card, player)
      _card.id = id
      _card.skillName = f.name
      if modify and RoomInstance then
        if not f.mute then
          player:broadcastSkillInvoke(f.name)
          RoomInstance:doAnimate("InvokeSkill", {
            name = f.name,
            player = player.id,
            skill_type = f.anim_type,
          })
        end
        RoomInstance:sendLog{
          type = "#FilterCard",
          arg = f.name,
          from = player.id,
          arg2 = card:toLogString(),
          arg3 = _card:toLogString(),
        }
      end
      card = _card
    end
    if card == nil then
      card = self:getCardById(id)
    end
    self.filtered_cards[id] = card
  end

  if modify then
    self.filtered_cards[id] = nil
    data.card = card
    return
  end
end

--- 添加一张现场打印的牌到游戏中。
---
--- 这张牌必须是clone出来的虚拟牌，不能有子卡；因为他接下来就要变成实体卡了
---@param card Card
function Engine:_addPrintedCard(card)
  assert(card:isVirtual() and #card.subcards == 0)
  table.insert(self.printed_cards, card)
  local id = -#self.printed_cards - 1
  card.id = id
  self.printed_cards[id] = card
end

--- 获知当前的Engine是跑在服务端还是客户端，并返回相应的实例。
---@return AbstractRoom
function Engine:currentRoom()
  if RoomInstance then
    return RoomInstance
  end
  return ClientInstance
end

--- 根据字符串获得这个技能或者这张牌的描述
---
--- 其实就是翻译了 ":" .. name 罢了
---@param name string @ 要获得描述的名字
---@param lang? string @ 要使用的语言，默认读取config
---@return string @ 描述
function Engine:getDescription(name, lang)
  return self:translate(":" .. name, lang)
end

return Engine
