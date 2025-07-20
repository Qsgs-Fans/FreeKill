--- 负责管理AbstractRoom中所有Card的位置，若在玩家的区域中，则管理所属玩家
---@class CardManager : Object
---@field public draw_pile integer[] @ 摸牌堆，是卡牌id数组
---@field public discard_pile integer[] @ 弃牌堆，是卡牌id数组
---@field public processing_area integer[] @ 处理区，是卡牌id数组
---@field public void integer[] @ 从游戏中除外区，是卡牌id数组
---@field public card_place table<integer, CardArea> @ 每个卡牌的id对应的区域，一张表
---@field public owner_map table<integer, integer> @ 每个卡牌id对应的主人，表的值是那个玩家的id，可能是nil
---@field public filtered_cards table<integer, Card> @ 见于Engine，其实在这
---@field public printed_cards table<integer, Card> @ 见于Engine，其实在这
---@field public next_print_card_id integer
---@field public card_marks table<integer, any> @ 用来存实体卡的card.mark
local CardManager = {}    -- mixin

function CardManager:initCardManager()
  self.draw_pile = {}
  self.discard_pile = {}
  self.processing_area = {}
  self.void = {}

  self.card_place = {}
  self.owner_map = {}

  self.filtered_cards = {}
  self.printed_cards = {}
  self.next_print_card_id = -2
  self.card_marks = {}
end

--- 设置一张卡牌的所在区域。内部私有函数，DIY别用
---@param cardId integer
---@param cardArea CardArea
---@param owner? integer
function CardManager:setCardArea(cardId, cardArea, owner)
  self.card_place[cardId] = cardArea
  self.owner_map[cardId] = owner
end

--- 获取一张牌所处的区域。若为多张牌且区域不同，返回Card.Unknown
---@param cardId? integer | Card @ 要获得区域的那张牌，可以是Card或者一个id
---@return CardArea @ 这张牌的区域
function CardManager:getCardArea(cardId)
  local cardIds = {}
  for _, cid in ipairs(Card:getIdList(cardId)) do
    local place = self.card_place[cid] or Card.Unknown
    table.insertIfNeed(cardIds, place)
  end
  return #cardIds == 1 and cardIds[1] or Card.Unknown
end

---@param cardId integer | Card @ 卡牌id
---@return integer? @ 拥有者的id
function CardManager:getCardOwner(cardId)
  if type(cardId) ~= "number" then
    assert(cardId and cardId:isInstanceOf(Card))
    cardId = cardId:getEffectiveId()
  end
  return self.owner_map[cardId] or nil
end

local playerAreas = { Player.Hand, Player.Equip, Player.Judge, Player.Special }

--- 根据area获取相关的卡牌id数组，若为玩家的区域则需指定玩家
---
--- 若不存在这种区域，需要返回nil
---@param area CardArea
---@param player? Player | PlayerId
---@param dup? boolean 是否返回复制 默认true
---@param special_name? string
function CardManager:getCardsByArea(area, player, dup, special_name)
  local ret
  if type(player) == "number" then player = Fk:currentRoom():getPlayerById(player) end
  dup = dup == nil and true or false

  if area == Card.Processing then
    ret = self.processing_area
  elseif area == Card.DrawPile then
    ret = self.draw_pile
  elseif area == Card.DiscardPile then
    ret = self.discard_pile
  elseif area == Card.Void then
    ret = self.void
  elseif table.contains(playerAreas, area) then
    assert(player ~= nil)
    if area == Player.Special then
      assert(special_name ~= nil)
      player.special_cards[special_name] = player.special_cards[special_name] or {}
      ret = player.special_cards[special_name]
    else
      ret = player.player_cards[area]
    end
  end

  if dup and ret then ret = table.simpleClone(ret) end
  return ret
end

--- 根据moveInfo来移动牌，先将牌从旧数组移动到新数组，再更新两个map表
---@param data MoveCardsData
---@param info MoveInfo
function CardManager:applyMoveInfo(data, info)
  local realFromArea = self:getCardArea(info.cardId)
  local room = Fk:currentRoom()
  local to
  if data.to then
    if type(data.to) == "number" then
      to = data.to
    else
      to = data.to.id
    end
  end

  local moveFrom = self.owner_map[info.cardId]
  local fromAreaIds = self:getCardsByArea(realFromArea,
  moveFrom and room:getPlayerById(moveFrom), false, info.fromSpecialName)

  if fromAreaIds == nil or not table.removeOne(fromAreaIds, info.cardId) then return false end

  local toAreaIds = self:getCardsByArea(data.toArea,
    to, false, data.specialName)

  if data.toArea == Card.DrawPile then
    local putIndex = data.drawPilePosition or 1
    if putIndex == -1 then
      putIndex = #self.draw_pile + 1
    elseif putIndex < 1 or putIndex > #self.draw_pile + 1 then
      putIndex = 1
    end

    table.insert(toAreaIds, putIndex, info.cardId)
  else
    table.insert(toAreaIds, info.cardId)
  end
  self:setCardArea(info.cardId, data.toArea, to)
end



--- 打印一张牌并存放于Void区
function CardManager:printCard(name, suit, number)
  local card = Fk:cloneCard(name, suit, number)

  local id = self.next_print_card_id
  card.id = id
  self.printed_cards[id] = card
  self.next_print_card_id = self.next_print_card_id - 1

  table.insert(self.void, card.id)
  self:setCardArea(card.id, Card.Void, nil)
  return card
end

-- misc

--- 展示一堆牌（注意，这样子是不会过锁视技的）
---@param cards integer|integer[]|Card|Card[] @ 要展示的牌
---@param from? Player
function CardManager:showCards(cards, from)
  cards = Card:getIdList(cards)
  local src
  if from then src = from.id end
  self:sendLog{
    type = "#ShowCard",
    from = src,
    card = cards,
  }
  self:doBroadcastNotify("ShowCard", json.encode{
    from = src,
    cards = cards,
  })
  self:sendFootnote(cards, {
    type = "##ShowCard",
    from = src,
  })

  self.logic:trigger(fk.CardShown, from, { cardIds = cards })
end

--- 准备房间牌堆
---@param seed integer @ 随机种子
function CardManager:prepareDrawPile(seed)
  local gamemode = Fk.game_modes[self.settings.gameMode]
  assert(gamemode)

  local draw_pile, void_pile = gamemode:buildDrawPile()

  table.shuffle(draw_pile, seed)
  self.draw_pile = draw_pile
  for _, id in ipairs(self.draw_pile) do
    self:setCardArea(id, Card.DrawPile, nil)
  end

  self.void = void_pile
  for _, id in ipairs(self.void) do
    self:setCardArea(id, Card.Void, nil)
  end
end

function CardManager:shuffleDrawPile(seed)
  if #self.draw_pile + #self.discard_pile == 0 then
    return
  end

  table.shuffle(self.discard_pile, seed)
  table.insertTable(self.draw_pile, self.discard_pile)
  for _, id in ipairs(self.discard_pile) do
    self:setCardArea(id, Card.DrawPile, nil)
  end
  self.discard_pile = {}
end

--- 筛选出某卡牌在指定区域内的子牌id数组
---@param card Card @ 要筛选的卡牌
---@param fromAreas? CardArea[] @ 指定的区域，填空则输出此卡牌所有子牌id
---@return integer[]
function CardManager:getSubcardsByRule(card, fromAreas)
  if card:isVirtual() and #card.subcards == 0 then
    return {}
  end

  local cardIds = {}
  fromAreas = fromAreas or Util.DummyTable
  for _, cardId in ipairs(card:isVirtual() and card.subcards or { card.id }) do
    if #fromAreas == 0 or table.contains(fromAreas, self:getCardArea(cardId)) then
      table.insert(cardIds, cardId)
    end
  end

  return cardIds
end

---从牌堆（或弃牌堆）内随机抽任意张牌
---@param pattern string @ 查找规则
---@param num? number @ 查找数量
---@param fromPile? "drawPile" | "discardPile" | "allPiles" @ 查找的来源区域，默认从牌堆内寻找
---@return integer[] @ id列表 可能空
function CardManager:getCardsFromPileByRule(pattern, num, fromPile)
  num = num or 1
  local pileToSearch = self.draw_pile
  if fromPile == "discardPile" then
    pileToSearch = self.discard_pile
  elseif fromPile == "allPiles" then
    pileToSearch = table.simpleClone(self.draw_pile)
    table.insertTable(pileToSearch, self.discard_pile)
  end

  if #pileToSearch == 0 then
    return {}
  end

  local matchedIds = {}
  for _, id in ipairs(pileToSearch) do
    if Fk:getCardById(id):matchPattern(pattern) then
      table.insert(matchedIds, id)
    end
  end

  if #matchedIds == 0 then
    return {}
  end

  local cardPack = {}

  local loopTimes = math.min(num, #matchedIds)
  local i
  for _ = 1, loopTimes do
    i = math.random(1, #matchedIds)
    table.insert(cardPack, matchedIds[i])
    table.remove(matchedIds, i)
  end

  return cardPack
end

function CardManager:toJsonObject()
  local printed_cards = {}
  for i = -2, -math.huge, -1 do
    local c = self.printed_cards[i]
    if not c then break end
    table.insert(printed_cards, { c.name, c.suit, c.number })
  end

  local cmarks = {}
  for k, v in pairs(self.card_marks) do
    cmarks[tostring(k)] = v
  end

  return {
    draw_pile = self.draw_pile,
    discard_pile = self.discard_pile,
    processing_area = self.processing_area,
    void = self.void,
    -- card_place和owner_map没必要；载入时setCardArea

    printed_cards = printed_cards,
    card_marks = cmarks,
  }
end

function CardManager:loadJsonObject(o)
  self.draw_pile = o.draw_pile
  self.discard_pile = o.discard_pile
  self.processing_area = o.processing_area
  self.void = o.void

  for _, id in ipairs(o.draw_pile) do self:setCardArea(id, Card.DrawPile, nil) end
  for _, id in ipairs(o.discard_pile) do self:setCardArea(id, Card.DiscardPile, nil) end
  for _, id in ipairs(o.processing_area) do self:setCardArea(id, Card.Processing, nil) end
  for _, id in ipairs(o.void) do self:setCardArea(id, Card.Void, nil) end

  for _, data in ipairs(o.printed_cards) do self:printCard(table.unpack(data)) end

  for cid, marks in pairs(o.card_marks) do
    for k, v in pairs(marks) do
      Fk:getCardById(tonumber(cid)):setMark(k, v)
    end
  end
end

return CardManager
