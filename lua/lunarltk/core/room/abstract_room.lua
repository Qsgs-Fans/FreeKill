local RoomBase = require "core.roombase"

-- 作Room和Client的基类，这二者有不少共通之处
---@class AbstractRoom : Base.RoomBase, CardManager
---@field public alive_players Player[] @ 所有存活玩家的数组
---@field public status_skills table<class, Skill[]> @ 这个房间中含有的状态技列表
---@field public skill_costs table<string, any> @ 用来存skill.cost_data
---@field public card_marks table<integer, any> @ 用来存实体卡的card.mark
---@field public disabled_packs string[] @ 未开启的扩展包名（是小包名，不是大包名）
---@field public disabled_generals string[] @ 未开启的武将
local AbstractRoom = RoomBase:subclass("AbstractRoom")

-- 此为勾式的手写泛型. 本意是extends RoomBase<Player>
---@class AbstractRoom : Base.RoomBase
---@field public players Player[]
---@field public observers Player[]
---@field public current Player
---@field public getPlayerById fun(self: AbstractRoom, id: integer): Player
---@field public getPlayerBySeat fun(self: AbstractRoom, seat: integer): Player
---@field public setCurrent fun(self: AbstractRoom, p: Player)
---@field public getCurrent fun(self: AbstractRoom): Player

local CardManager = require 'lunarltk.core.room.card_manager'
AbstractRoom:include(CardManager)

local ReqInvoke = require 'lunarltk.core.request_type.invoke'
local ReqActive = require 'lunarltk.core.request_type.active_skill'
local ReqResponse = require 'lunarltk.core.request_type.response_card'
local ReqUse = require 'lunarltk.core.request_type.use_card'
local ReqPlay = require 'lunarltk.core.request_type.play_card'

function AbstractRoom:initialize()
  RoomBase.initialize(self)
  self.alive_players = {}

  self:initCardManager()
  self.status_skills = {}
  for class, skills in pairs(Fk.global_status_skill) do
    self.status_skills[class] = {table.unpack(skills)}
  end

  self.skill_costs = {}

  self:addRequestHandler("AskForSkillInvoke", ReqInvoke)
  self:addRequestHandler("AskForUseActiveSkill", ReqActive)
  self:addRequestHandler("AskForResponseCard", ReqResponse)
  self:addRequestHandler("AskForUseCard", ReqUse)
  self:addRequestHandler("PlayCard", ReqPlay)
end

--- 获得拥有某一张牌的玩家。
---@param cardId integer | Card @ 要获得主人的那张牌，可以是Card实例或者id
---@return Player? @ 这张牌的主人，可能返回nil
function AbstractRoom:getCardOwner(cardId)
  local ret = CardManager.getCardOwner(self, cardId)
  return ret and self:getPlayerById(ret)
end

--- 获得当前房间中的当前回合角色。
---
--- 游戏开始时及每轮开始时当前回合还未正式开始，该函数可能返回nil。
---@return Player? @ 当前回合角色
function AbstractRoom:getCurrent()
  if self.current and self.current.phase ~= Player.NotActive then
    return self.current
  end
  return nil
end

--- 在判定或使用流程中，将使用或判定牌应用锁视转化，并返回转化后的牌
---@param id integer @ 牌id
---@param player Player @ 使用者或判定角色
---@param judgeEvent boolean? @ 是否为判定事件
---@return Card @ 返回应用锁视后的牌
function AbstractRoom:filterCard(id, player, judgeEvent)
  local card = Fk:getCardById(id, true)
  local filters = self.status_skills[FilterSkill] or Util.DummyTable---@type FilterSkill[]

  if #filters == 0 then
    self.filtered_cards[id] = nil
    return card
  end

  local modify = false
  for _, f in ipairs(filters) do
    if f:cardFilter(card, player, judgeEvent) then
      local new_card = f:viewAs(player, card)
      if new_card then
        modify = true
        local skill_name = f:getSkeleton().name
        new_card.id = id
        new_card.skillName = skill_name
        if self:isInstanceOf(Room) and not f.mute then
          ---@cast self Room
          ---@cast player ServerPlayer
          player:broadcastSkillInvoke(skill_name)
          self:doAnimate("InvokeSkill", {
            name = skill_name,
            player = player.id,
            skill_type = f.anim_type,
          })
        end
        card = new_card
        self.filtered_cards[id] = card
      end
    end
  end
  if not modify then
    self.filtered_cards[id] = nil
  end
  return card
end


function AbstractRoom:serialize()
  local o = RoomBase.serialize(self)
  local card_manager = CardManager.serialize(self)
  o.card_manager = card_manager

  return o
end

function AbstractRoom:deserialize(o)
  CardManager.deserialize(self, o.card_manager)

  RoomBase.deserialize(self, o)

  self.alive_players = table.filter(self.players, function(p)
    return p:isAlive()
  end)
end

-- TODO 这个好像是三国杀特有？

-- 判断当前模式是否为某类模式
---@param mode string @ 需要判定的模式类型
---@return boolean
function AbstractRoom:isGameMode(mode)
  return table.contains(Fk.main_mode_list[mode] or {}, self:getSettings('gameMode'))
end

return AbstractRoom
