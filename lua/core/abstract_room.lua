-- 作Room和Client的基类，这二者有不少共通之处
---@class AbstractRoom : Object
---@fiele public players Player[] @ 房内参战角色们
---@field public alive_players Player[] @ 所有存活玩家的数组
---@field public observers Player[] @ 看戏的
---@field public current Player @ 当前行动者
---@field public status_skills table<class, Skill[]> @ 这个房间中含有的状态技列表
---@field public filtered_cards table<integer, Card> @ 见于Engine，其实在这
---@field public printed_cards table<integer, Card> @ 同上
---@field public skill_costs table<string, any> @ 用来存skill.cost_data
---@field public card_marks table<integer, any> @ 用来存实体卡的card.mark
---@field public banners table<string, any> @ 全局mark
local AbstractRoom = class("AbstractRoom")

function AbstractRoom:initialize()
  self.players = {}
  self.alive_players = {}
  self.observers = {}
  self.current = nil

  self.status_skills = {}
  for class, skills in pairs(Fk.global_status_skill) do
    self.status_skills[class] = {table.unpack(skills)}
  end

  self.filtered_cards = {}
  self.printed_cards = {}
  self.skill_costs = {}
  self.card_marks = {}
  self.banners = {}
end

-- 仅供注释，其余空函数一样
---@param id integer
---@return Player?
function AbstractRoom:getPlayerById(id) end

--- 获取一张牌所处的区域。
---@param cardId integer | Card @ 要获得区域的那张牌，可以是Card或者一个id
---@return CardArea @ 这张牌的区域
function AbstractRoom:getCardArea(cardId) return Card.Unknown end

function AbstractRoom:setBanner(name, value)
  if value == 0 then value = nil end
  self.banners[name] = value
end

function AbstractRoom:getBanner(name)
  return self.banners[name]
end

return AbstractRoom
