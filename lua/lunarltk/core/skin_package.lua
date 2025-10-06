---@class SkinPackageContent

---@class SkinPackageSpec
---@field path string
---@field content SkinPackageContent[]

---@class SkinPackage : SkinPackageSpec, Object
SkinPackage = class("Base.SkinPackage")

function SkinPackage:initialize(spec)
  self.name = spec.name
  self.content = spec.content
end

return SkinPackage