---@class QmlComponent
---@field uri? string
---@field name? string
---@field url? string
---@field prop? { [string]: any }

---@class BoardGameSpec
---@field name string
---@field engine Base.Engine engine实例
---@field client_klass any client类
---@field room_klass any room类
---@field page QmlComponent 主游戏页面数据

--- 定义某款桌游。桌游大类只负责：
---
--- * 包加载时，将拓展包加载到相应的Engine
--- * 服务端newroom时创建相应类型的Room
--- * 客户端enterRoom时创建相应的client换掉已有的
--- * 客户端游戏开始时向GUI中加载相应的Page
---@class BoardGame : BoardGameSpec, Object
local BoardGame = class("Base.BoardGame")

function BoardGame:initialize(spec)
  self.name = spec.name
  self.engine = spec.engine
  self.client_klass = spec.client_klass
  self.room_klass = spec.room_klass
  self.page = spec.page
end

return BoardGame
