--加载后的skin保存方式，一个武将的一个skin通过SkinContent类保存
---@class SkinContent
---@field name string
---@field path string

---@class SkinPackageContent
---@field enabled_generals table
---@field skins table

---@class SkinPackageSpec
---@field path? string
---@field url? string -- 网络链接
---@field content SkinPackageContent[]

---@class SkinPackage : SkinPackageSpec, Object
SkinPackage = class("Base.SkinPackage")

function SkinPackage:initialize(spec)
  self.name = spec.name
  self.content = spec.content
end

return SkinPackage