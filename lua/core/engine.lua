---@class Base.Engine : Object
---@field public packages table<string, Package> @ 所有拓展包的列表
---@field public package_names string[] @ 含所有拓展包名字的数组，为了方便排序
---@field public skills table<string, Skill> @ 所有的技能
---@field public skill_skels table<string, SkillSkeleton> @ 所有的SkillSkeleton
---@field public related_skills table<string, Skill[]> @ 所有技能的关联技能
---@field public global_trigger TriggerSkill[] @ 所有的全局触发技
---@field public global_status_skill table<class, Skill[]> @ 所有的全局状态技
---@field public ui_packages table<string, UIPackage> @ UI
local Engine = class("Base.Engine")

function Engine:initialize()
  self.packages = {}    -- name --> Package
  self.package_names = {}
  self.skills = {}    -- name --> Skill
  self.skill_skels = {}    -- name --> SkillSkeleton
  self.related_skills = {} -- skillName --> relatedSkill[]
  self.global_trigger = {}
  self.global_status_skill = {}
  self.ui_packages = {}
end

---@deprecated
function Engine:loadPackage(pack)
  pack:install(self)
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

---@param name string @ 要获得描述的名字
---@param lang? string @ 要使用的语言，默认读取config
---@param player Player @ 绑定角色，用于获取技能的动态描述
---@param with_effectable? boolean @ 是否需要加上无效红字显示
---@return string @ 描述
function Engine:getSkillName(name, lang, player, with_effectable)
  lang = lang or (Config.language or "zh_CN")
  local skill = self.skills[name]
  local _name
  if skill.skeleton then -- 新框架
    _name = skill.skeleton:getDynamicName(player, lang)
  end
  if type(_name) == "string" and _name ~= "" then
    _name = Fk:translate(_name, lang)
  else
    _name = Fk:translate(name, lang)
  end
  if with_effectable then
    return _name .. (skill:isEffectable(player) and "" or Fk:translate("skill_invalidity", lang)) -- 无效显示
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
  local skill = self.skills[name]
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
        local descFormatted = Fk:translate(":" .. descSplit[1], lang)
        if descFormatted ~= ":" .. descSplit[1] then
          for i = 2, #descSplit do
            local curDesc = Fk:translate(descSplit[i], lang)
            descFormatted = descFormatted:gsub("{" .. (i - 1) .. "}", curDesc)
          end

          return descFormatted
        end

        return desc
      end

      return descFormatter(dynamicDesc)
    end
  end

  return Fk:translate(":" .. name, lang)
end

local UIPackage = require "core.ui_package"
---@param uipak UIPackageSpec
function Engine:addUIPackage(uipak)
  self.ui_packages[uipak.name] = UIPackage:new(uipak)
end

function Engine:listUIPackages()
  local arr = {}
  for k, v in pairs(self.ui_packages) do
    if arr[v.boardgame] then
      table.insert(arr[v.boardgame], k)
    else
      arr[v.boardgame] = {k}
    end
  end
  return arr
end

---@param name string @ UIPack名字
---@return UIPackage
function Engine:getUIPackage(name)
  return self.ui_packages[name]
end


return Engine
