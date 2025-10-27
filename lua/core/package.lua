---@class Base.Package : Object
---@field public name string @ 拓展包的名字
---@field public extensionName string @ 拓展包对应的mod文件夹的名字。
---@field public customPages? W.PageButtonSpec[] @ 这个拓展包注册的额外页面
local Package = class("Base.Package")

function Package:initialize(name)
  assert(type(name) == "string")
  self.name = name
  self.extensionName = name -- used for get assets
end

--- 把自己加载到对应engine中，需要具体Package类重写
---@param engine Base.Engine
function Package:install(engine)
end

return Package
