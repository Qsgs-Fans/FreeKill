---@class Package : Object
---@field public name string
---@field public extensionName string
---@field public type PackageType
---@field public generals General[]
---@field public extra_skills Skill[]
---@field public related_skills table<string, string>
---@field public cards Card[]
---@field public game_modes GameMode[]
local Package = class("Package")

---@alias PackageType integer

Package.GeneralPack = 1
Package.CardPack = 2
Package.SpecialPack = 3

function Package:initialize(name, _type)
  assert(type(name) == "string")
  assert(type(_type) == "nil" or type(_type) == "number")
  self.name = name
  self.extensionName = name -- used for get assets
  self.type = _type or Package.GeneralPack

  self.generals = {}
  self.extra_skills = {}  -- skill not belongs to any generals, like "jixi"
  self.related_skills = {}
  self.cards = {}
  self.game_modes = {}
end

---@return Skill[]
function Package:getSkills()
  local ret = {table.unpack(self.related_skills)}
  if self.type == Package.GeneralPack then
    for _, g in ipairs(self.generals) do
      for _, s in ipairs(g.skills) do
        table.insert(ret, s)
      end
    end
  end
  return ret
end

---@param general General
function Package:addGeneral(general)
  assert(general.class and general:isInstanceOf(General))
  table.insertIfNeed(self.generals, general)
end

---@param card Card
function Package:addCard(card)
  assert(card.class and card:isInstanceOf(Card))
  card.package = self
  table.insert(self.cards, card)
end

---@param cards Card[]
function Package:addCards(cards)
  for _, card in ipairs(cards) do
    self:addCard(card)
  end
end

function Package:addGameMode(game_mode)
  table.insert(self.game_modes, game_mode)
end

return Package
