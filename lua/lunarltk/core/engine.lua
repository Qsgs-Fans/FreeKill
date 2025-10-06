-- SPDX-License-Identifier: GPL-3.0-or-later

local modManager = require "core.mod_manager"
local baseEngine = require "core.engine"

--- Engine是整个FreeKill赖以运行的核心。
---
--- 它包含了FreeKill涉及的所有武将、卡牌、游戏模式等等
---
--- 同时也提供了许多常用的函数。
---
---@class Engine : Base.Engine, Base.ModManager
---@field public generals table<string, General> @ 所有武将
---@field public same_generals table<string, string[]> @ 所有同名武将组合
---@field public lords string[] @ 所有主公武将，用于常备主公
---@field public all_card_types table<string, Card> @ 所有的卡牌类型以及一张样板牌
---@field public all_card_names string[] @ 有序的所有的卡牌牌名，顺序：基本牌（杀置顶），普通锦囊，延时锦囊，按副类别排序的装备
---@field public cards Card[] @ 所有卡牌
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
---@field public target_tips table<string, TargetTipSpec> @ 选择目标提示对应表
---@field public choose_general_rule table<string, ChooseGeneralSpec> @ 选将框操作方法表
---@field public skin_packages table<string, string[]> @ Skins
local Engine = baseEngine:subclass("Engine")
Engine:include(modManager)

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

  baseEngine.initialize(self)
  self:initModManager()

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

  self.generals = {}    -- name --> General
  self.same_generals = {}
  self.lords = {}     -- lordName[]
  self.all_card_types = {}
  self.all_card_names = {}
  self.cards = {}     -- Card[]
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
  self.target_tips = {}
  self.choose_general_rule = {}
  self.skin_packages = {}

  self:loadPackages()

  -- 唉，杀批的Engine又搞特殊了
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

  self:setLords()
  self:loadCardNames()
  self:loadDisabled()
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

-- Don't do this
Engine.reloadPackages = Util.DummyFunc

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

function Engine:getSkinsByGeneral(general)
  return self.skin_packages[general] or {}
end

return Engine
