local common = require 'ui_emu.common'
local OKScene = require 'ui_emu.okscene'
local CardItem = common.CardItem
local Photo = common.Photo
local SkillButton = common.SkillButton

---@class RoomScene: OKScene
local RoomScene = OKScene:subclass("RoomScene")
RoomScene.scene_name = "Room"

---@param parent RequestHandler
function RoomScene:initialize(parent)
  OKScene.initialize(self, parent)
  local player = parent.player

  for _, p in ipairs(parent.room.alive_players) do
    self:addItem(Photo:new(self, p.id))
  end
  for _, cid in ipairs(player:getCardIds("h")) do
    self:addItem(CardItem:new(self, cid))
  end
  for _, skill in ipairs(player:getAllSkills()) do
    if skill:isInstanceOf(ActiveSkill) or skill:isInstanceOf(ViewAsSkill) then
      self:addItem(SkillButton:new(self, skill.name))
    end
  end
end

function RoomScene:unselectOtherCards(cid)
  local dat = { selected = false }
  for id, _ in pairs(self:getAllItems("CardItem")) do
    if id ~= cid then
      self:update("CardItem", id, dat)
    end
  end
end
function RoomScene:unselectOtherTargets(pid)
  local dat = { selected = false }
  for id, _ in pairs(self:getAllItems("Photo")) do
    if id ~= pid then
      self:update("Photo", id, dat)
    end
  end
end
RoomScene.unselectAllCards = RoomScene.unselectOtherCards
RoomScene.unselectAllTargets = RoomScene.unselectOtherTargets

-- 若所有角色都不可选则将state设为normal; 反之只要有可选的就设candidate
-- 这样更美观
function RoomScene:updateTargetEnability(pid, enabled)
  local photoTab = self.items["Photo"]
  local photo = photoTab[pid]
  self:update("Photo", pid, { enabled = not not enabled })
  if enabled then
    if photo.state == "normal" then
      for id, _ in pairs(photoTab) do
        self:update("Photo", id, { state = "candidate" })
      end
    end
  else
    local allDisabled = true
    for _, v in pairs(photoTab) do
      if v.enabled then
        allDisabled = false
        break
      end
    end
    if allDisabled then
      for id, _ in pairs(photoTab) do
        self:update("Photo", id, { state = "normal" })
      end
    end
  end
end

function RoomScene:disableAllTargets()
  for id, _ in pairs(self.items["Photo"]) do
    self:update("Photo", id, {
      state = "normal",
      selected = false,
      enabled = false,
    })
  end
end

return RoomScene
