-- SPDX-License-Identifier: GPL-3.0-or-later

--- General用来描述一个武将。
---
--- 所谓武将，就是所属包、武将基础信息的集合。
---
--- 也许···类似于身份证？
---
---@class General : Object
---@field public package Package @ 武将所属包
---@field public name string @ 武将名字
---@field public trueName string @ 武将真名，也许可以分辨标界？
---@field public kingdom string @ 武将所属势力
---@field public subkingdom string @ 武将副势力
---@field public hp integer @ 武将初始体力
---@field public maxHp integer @ 武将初始最大体力
---@field public mainMaxHpAdjustedValue integer @ 主将体力上限调整
---@field public deputyMaxHpAdjustedValue integer @ 副将体力上限调整
---@field public shield integer @ 初始护甲
---@field public gender Gender @ 武将性别
---@field public skills Skill[] @ 武将技能（0.5.5后无效）
---@field public other_skills string[] @ 武将身上属于其他武将的技能，通过字符串调用（0.5.5后合并skills）
---@field public related_skills Skill[] @ 武将相关的不属于其他武将的技能，例如邓艾的急袭
---@field public related_other_skills string [] @ 武将相关的属于其他武将的技能，例如孙策的英姿
---@field public all_skills table @ 武将的所有技能，包括相关技能和属于其他武将的技能
---@field public companions string [] @ 有珠联璧合关系的武将
---@field public headnote string @ 顶注。在武将介绍界面出现
---@field public endnote string @ 尾注。在武将介绍界面出现
---@field public hidden boolean @ 不在选将框里出现，可以点将，可以在武将一览里查询到
---@field public total_hidden boolean @ 完全隐藏
General = class("General")

---@alias Gender integer

--- 男性
General.Male = 1
--- 女性
General.Female = 2
--- 双性
General.Bigender = 3
--- 无性
General.Agender = 4

--- 构造函数，不可随意调用。
---@param package Package @ 武将所属包
---@param name string @ 武将名字
---@param kingdom string @ 武将所属势力
---@param hp integer @ 武将初始体力
---@param maxHp integer @ 武将初始最大体力
---@param gender Gender @ 武将性别
function General:initialize(package, name, kingdom, hp, maxHp, gender)
  self.package = package
  self.name = name
  local name_splited = name:split("__")
  self.trueName = name_splited[#name_splited]

  self.kingdom = kingdom
  self.hp = hp
  self.maxHp = maxHp or hp
  self.gender = gender or General.Male
  self.mainMaxHpAdjustedValue = 0
  self.deputyMaxHpAdjustedValue = 0
  self.shield = 0
  self.subkingdom = nil

  self.skills = {}    -- skills first added to this general
  self.other_skills = {}  -- skill belongs other general, e.g. "mashu" of pangde
  self.related_skills = {} -- skills related to this general, but not first added to it, e.g. "jixi" of dengai
  self.related_other_skills = {} -- skills related to this general and belong to other generals, e.g. "yingzi" of sunce
  self.all_skills = {}

  self.companions = {}

  self.headnote = ""
  self.endnote = ""

  package:addGeneral(self)
end

function General:__tostring()
  return string.format("<General %s>", self.name)
end

local CBOR_TAG_GENERAL = 33005
function General:__tocbor()
  return cbor.encode(cbor.tagged(CBOR_TAG_GENERAL, self.name))
end
function General:__touistring()
  return Fk:translate(self.name)
end
function General:__toqml()
  return {
    uri = "Fk.Components.LunarLTK",
    name = "GeneralCardItem",

    -- TODO 虚拟卡
    prop = {
      name = self.name,
    },
  }
end
cbor.tagged_decoders[CBOR_TAG_GENERAL] = function(v)
  return Fk.generals[v]
end


--- 为武将增加技能
---@param skill Skill|string @ （单个）武将技能
function General:addSkill(skill)
  if (type(skill) == "string") then
    table.insert(self.other_skills, skill) -- 0.5.4以前只有其他武将的技能会进来，现在是所有
    table.insert(self.all_skills, {skill, false}) -- only for UI
  elseif (skill.class and skill.class:isSubclassOf(Skill)) then -- 牢
    table.insert(self.skills, skill)
    table.insert(self.all_skills, {skill.name, false}) -- only for UI
    skill.package = self.package
  end
end

---@param skill_list string[]
function General:addSkills(skill_list)
  for _, skill in ipairs(skill_list) do
    self:addSkill(skill)
  end
end

--- 为武将增加相关技能
---@param skill Skill|string @ （单个）武将技能
function General:addRelatedSkill(skill)
  if (type(skill) == "string") then
    table.insert(self.related_other_skills, skill) -- 0.5.4以前只有其他角色的技能会进来，现在是所有
    table.insert(self.all_skills, {skill, true}) -- only for UI
  elseif (skill.class and skill.class:isSubclassOf(Skill)) then
    table.insert(self.related_skills, skill)
    table.insert(self.all_skills, {skill.name, true}) -- only for UI
    Fk:addSkill(skill)
    skill.package = self.package
  end
end

---@param skill_list string[]
function General:addRelatedSkills(skill_list)
  for _, skill in ipairs(skill_list) do
    self:addRelatedSkill(skill)
  end
end

--- 获取武将牌上的技能名。
---@param include_lord? boolean @ 是否包含主公技。默认否
---@return string[]
function General:getSkillNameList(include_lord)
  local ret = {}
  local other_skills = table.map(self.other_skills, Util.Name2SkillMapper)
  local skills = table.connect(self.skills, other_skills)
  for _, skill in ipairs(skills) do
    if include_lord or not skill:hasTag(Skill.Lord) then
      table.insert(ret, skill.name)
    end
  end

  -- table.insertTable(ret, self.other_skills)
  return ret
end

--- 为武将增加珠联璧合关系武将（1个或多个）。
---@param name string|string[]  @ 武将名（表）
function General:addCompanions(name)
  if type(name) == "table" then
    table.insertTable(self.companions, name)
  elseif type(name) == "string" then
    table.insert(self.companions, name)
  end
end

--- 是否与另一武将构成珠联璧合关系。
---@param other General @ 另一武将
---@return boolean
function General:isCompanionWith(other)
  assert(other:isInstanceOf(General))
  if self == other then return false end
  return table.contains(self.companions, other.name) or table.contains(other.companions, self.name)
    or (not not string.find(self.name, "lord") and (other.kingdom == self.kingdom or other.subkingdom == self.kingdom))
    or (not not string.find(other.name, "lord") and (self.kingdom == other.kingdom or self.subkingdom == other.kingdom))
    or (not not string.find(self.name, "all_comp") or not not string.find(other.name, "all_comp")) -- all_comp 所有都珠联璧合
end

return General
