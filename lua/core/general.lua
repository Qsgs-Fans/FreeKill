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
---@field public hp integer @ 武将初始体力
---@field public maxHp integer @ 武将初始最大体力
---@field public shield integer @ 初始护甲
---@field public gender Gender @ 武将性别
---@field public skills Skill[] @ 武将技能
---@field public other_skills string[] @ 武将身上属于其他武将的技能，通过字符串调用
---@field public related_skills Skill[] @ 武将相关的不属于其他武将的技能，例如邓艾的急袭
---@field public related_other_skills string [] @ 武将相关的属于其他武将的技能，例如孙策的英姿
---@field public hidden boolean
---@field public total_hidden boolean
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
  self.shield = 0

  self.skills = {}    -- skills first added to this general
  self.other_skills = {}  -- skill belongs other general, e.g. "mashu" of pangde
  self.related_skills = {} -- skills related to this general, but not first added to it, e.g. "jixi" of dengai
  self.related_other_skills = {} -- skills related to this general and belong to other generals, e.g. "yingzi" of sunce

  package:addGeneral(self)
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

function General:getSkillNameList(include_lord)
  local ret = table.map(self.skills, Util.NameMapper)
  table.insertTable(ret, self.other_skills)

  if not include_lord then
  end
  return ret
end

return General
