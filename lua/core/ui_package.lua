---@class UIPackageSpec
---@field name string
---@field boardgame string
---@field page QmlComponent

---@class UIPackage : UIPackageSpec, Object
UIPackage = class("Base.UIPackage")

function UIPackage:initialize(spec)
  self.name = spec.name
  self.boardgame = spec.boardgame
  self.page = spec.page
end

return UIPackage