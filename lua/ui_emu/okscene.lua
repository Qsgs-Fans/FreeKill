local base = require 'ui_emu.base'
local control = require 'ui_emu.control'
local Scene = base.Scene
local Button = control.Button

---@class OKScene: Scene
local OKScene = Scene:subclass("OKScene")
OKScene.scene_name = "Room"

---@param parent RequestHandler
function OKScene:initialize(parent)
  Scene.initialize(self, parent)

  self:addItem(Button:new(self, "OK"))
  self:addItem(Button:new(self, "Cancel"))
end

return OKScene
