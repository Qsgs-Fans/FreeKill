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
---@field public skills Skill[] @ 武将技能
---@field public other_skills string[] @ 武将身上属于其他武将的技能，通过字符串调用
---@field public related_skills Skill[] @ 武将相关的不属于其他武将的技能，例如邓艾的急袭
---@field public related_other_skills string [] @ 武将相关的属于其他武将的技能，例如孙策的英姿
---@field public companions string [] @ 有珠联璧合关系的武将
---@field public hidden boolean @ 不在选将框里出现，可以点将，可以在武将一览里查询到
---@field public total_hidden boolean @ 完全隐藏
General = class("General")

---@alias Gender integer

General.Male = 1
General.Female = 2
General.Bigender = 3
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

  self.companions = {}

  package:addGeneral(self)
end

function General:__tostring()
  return string.format("<General %s>", self.name)
end

--- 为武将增加技能，需要注意增加其他武将技能时的处理方式。
---@param skill Skill @ （单个）武将技能
function General:addSkill(skill)
  if (type(skill) == "string") then
    table.insert(self.other_skills, skill)
  elseif (skill.class and skill.class:isSubclassOf(Skill)) then
    table.insert(self.skills, skill)
    skill.package = self.package
  end
end

--- 为武将增加相关技能，需要注意增加其他武将技能时的处理方式。
---@param skill Skill @ （单个）武将技能
function General:addRelatedSkill(skill)
  if (type(skill) == "string") then
    table.insert(self.related_other_skills, skill)
  elseif (skill.class and skill.class:isSubclassOf(Skill)) then
    table.insert(self.related_skills, skill)
    Fk:addSkill(skill)
    skill.package = self.package
  end
end

--- 获取武将所有技能。
function General:getSkillNameList(include_lord)
  local ret = table.map(self.skills, Util.NameMapper)
  table.insertTable(ret, self.other_skills)

  if not include_lord then
  end
  return ret
end

--- 为武将增加珠联璧合关系武将（1个或多个），只需写trueName。
---@param name string[]  @ 武将真名（表）
function General:addCompanions(name)
  if type(name) == "table" then
    table.insertTable(self.companions, name)
  elseif type(name) == "string" then
    table.insert(self.companions, name)
  end
end

return General
