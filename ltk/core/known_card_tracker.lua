--- 表示某个区域的已知牌
---@class KnownCards
---@field known_cards integer[] 确定的已知牌，必有n张暗牌或明牌对应
---@field uncertain_cards integer[] 不确定的已知牌，对应任意张暗牌

---@return KnownCards
local function createKnownCards()
  return {
    known_cards = {},
    uncertain_cards = {},
  }
end

--- 记牌器，可记录牌堆、处理区、弃牌堆、角色区域内的牌（不记录void区）
---@class KnownCardTracker: Object
---@field player Player 主视角
---@field player_cards { [integer]: { [integer|string]: KnownCards } }
--- 其他人的记牌，包含三区域（int键）和额外牌堆（string键）
---@field draw_pile KnownCards 摸牌堆的记牌
---@field discard_pile KnownCards 弃牌堆的记牌
---@field processing_area KnownCards 处理区的记牌
---@field void KnownCards 处理区的记牌
---@field draw_pile_order integer[] 摸牌堆特有的顺序记牌
local KnownCardTracker = class("KnownCardTracker")

function KnownCardTracker:initialize(player)
  self.player = player

  self.player_cards = {}
  self.draw_pile = createKnownCards()
  self.discard_pile = createKnownCards()
  self.processing_area = createKnownCards()
  self.void = createKnownCards()
  self.draw_pile_order = {}
end

--- 根据area获取相关的已知卡牌，若为玩家的区域则需指定玩家
---
--- 若不存在这种区域，需要返回nil
---@param area CardArea
---@param player? Player
---@param special_name? string
function KnownCardTracker:getKnownCardsByArea(area, player, special_name)
  local ret
  local playerAreas = { Player.Hand, Player.Equip, Player.Judge, Player.Special }
  if type(player) == "number" then player = Fk:currentRoom():getPlayerById(player) end

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
    local pid = player.id
    self.player_cards[pid] = self.player_cards[pid] or {}
    local t = self.player_cards[pid]

    if area == Player.Special then
      assert(special_name ~= nil)
      t[special_name] = t[special_name] or createKnownCards()
      ret = t[special_name]
    else
      t[area] = t[area] or createKnownCards()
      ret = t[area]
    end
  end

  return ret
end

---@class TrackerMoveInfo
---@field ids integer[]
---@field visible_ids integer[]
---@field unknown_ids integer[]
---@field player Player?
---@field area CardArea
---@field specialName string?

---@param moves MoveCardsData[]
---@return { [string]: TrackerMoveInfo }, { [string]: TrackerMoveInfo }, string
function KnownCardTracker:splitMoveDatas(moves, visible_data)
  local lose_infos = {}   ---@type { [string]: TrackerMoveInfo }
  local add_infos = {}    ---@type { [string]: TrackerMoveInfo }
  local drawpileDirection -- 记载一下是不是牌堆顶底，不考虑同时移动的bug场景
  for _, move in ipairs(moves) do
    if move.drawPilePosition == -1 then
      drawpileDirection = "bottom"
    elseif move.drawPilePosition == 1 or (move.drawPilePosition == nil and move.toArea == Card.DrawPile) then
      drawpileDirection = "top"
    end

    for _, info in ipairs(move.moveInfo) do
      local fromk = tostring(move.from) .. tostring(info.fromArea) .. tostring(info.fromSpecialName)
      local tok = tostring(move.to) .. tostring(move.toArea) .. tostring(move.specialName)
      lose_infos[fromk] = lose_infos[fromk] or {
        ids = {},
        visible_ids = {},
        unknown_ids = {},
        player = move.from,
        area = info.fromArea,
        specialName = info.fromSpecialName,
      }

      add_infos[tok] = add_infos[tok] or {
        ids = {},
        visible_ids = {},
        unknown_ids = {},
        player = move.to,
        area = move.toArea,
        specialName = move.specialName,
      }

      -- 若为牌堆中失去牌且此牌被牌堆顺序标记为可见且明确是顶底，则认为可见
      if info.fromArea == Card.DrawPile then
        if move.drawPilePosition == nil then drawpileDirection = "top" end
        if drawpileDirection then
          if table.contains(self.draw_pile_order, info.cardId) then
            visible_data[info.cardId] = true
          end
        end
      end

      table.insert(lose_infos[fromk].ids, info.cardId)
      table.insert(add_infos[tok].ids, info.cardId)
      if visible_data[info.cardId] then
        table.insert(lose_infos[fromk].visible_ids, info.cardId)
        table.insert(add_infos[tok].visible_ids, info.cardId)
      else
        table.insert(lose_infos[fromk].unknown_ids, info.cardId)
        table.insert(add_infos[tok].unknown_ids, info.cardId)
      end
    end
  end

  return lose_infos, add_infos, drawpileDirection
end

function KnownCardTracker:trackLoseFromDrawPile(info, drawpileDirection)
  local draw_pile = Fk:currentRoom().draw_pile

  -- 若移出了牌堆，且明确是从牌堆顶或底或者全部明着移除 则删除
  if drawpileDirection or #info.unknown_ids == 0 then
    -- FIXME 实在不知道怎么做了，开透吧
    local visible = {}
    for _, id in ipairs(self.draw_pile_order) do
      if id ~= -1 then visible[id] = true end
    end
    self.draw_pile_order = table.map(draw_pile, function(id)
      return visible[id] and id or -1
    end)
  else
    -- 否则只要有未知牌移出了就干脆清空
    if #self.draw_pile_order - #info.ids ~= #draw_pile then
      self.draw_pile_order = table.map(draw_pile, function() return -1 end)
    end
  end
end

---@param info TrackerMoveInfo
function KnownCardTracker:trackLoseCards(info, drawpileDirection)
  local player = self.player

  local track = self:getKnownCardsByArea(info.area, info.player, info.specialName)
  local cids = Fk:currentRoom():getCardsByArea(info.area, info.player, false, info.specialName)

  -- 若移走了可见牌，则从已知牌中删除对应id
  for _, id in ipairs(info.visible_ids) do
    table.removeOne(track.known_cards, id)
    table.removeOne(track.uncertain_cards, id)
  end

  -- 若移走了未知牌，则将不可见的已知牌设为不确定的牌
  if #info.unknown_ids > 0 then
    local visible_cards = table.filter(cids, function(id) return player:cardVisible(id) end)

    local known_unvisible_cards = table.filter(track.known_cards, function(id)
      return not table.contains(visible_cards, id)
    end)
    table.insertTableIfNeed(track.uncertain_cards, known_unvisible_cards)
    track.known_cards = visible_cards
  end

  -- 判断是否全是已知牌以适当清空不确定的牌
  if #track.known_cards == #cids then
    track.uncertain_cards = {}
  end

  -- 牌堆特化
  if info.area == Card.DrawPile then
    self:trackLoseFromDrawPile(info, drawpileDirection)
  end
end

function KnownCardTracker:trackAddToDrawPile(info, drawpileDirection)
  -- 若移入了牌堆，则按牌堆顶底标记已知情况 其余情况不管
  local draw_pile = Fk:currentRoom().draw_pile
  if #self.draw_pile_order + #info.ids ~= #draw_pile then
    -- 若不知道为什么失去同步了则重置为全未知
    self.draw_pile_order = table.map(draw_pile, function() return -1 end)
  else
    -- 否则按置入顺序加入-1
    for _ = 1, #info.ids do
      if drawpileDirection == "top" then
        table.insert(self.draw_pile_order, 1, -1)
      elseif drawpileDirection == "bottom" then
        table.insert(self.draw_pile_order, -1)
      else
        -- 不知道顺序，直接清空牌堆记牌
        self.draw_pile_order = table.map(draw_pile, function() return -1 end)
      end
    end
  end

  -- 如果明确了这些牌移动到牌堆顶底，则可将牌堆对应位置的卡牌标记为已知
  if drawpileDirection then
    for _, id in ipairs(info.visible_ids) do
      local idx = table.indexOf(draw_pile, id)
      if idx ~= -1 then
        self.draw_pile_order[idx] = id
      end
    end
  end
end

---@param info TrackerMoveInfo
function KnownCardTracker:trackAddCards(info, drawpileDirection)
  local track = self:getKnownCardsByArea(info.area, info.player, info.specialName)
  for _, id in ipairs(info.visible_ids) do
    -- 若移入了可见牌，track的已知牌中增加对应id
    table.insert(track.known_cards, id)
  end

  -- 若移进了未知牌，则无事发生
  -- pass

  -- 牌堆特化
  if info.area == Card.DrawPile then
    self:trackAddToDrawPile(info, drawpileDirection)
  end
end

---@param moves MoveCardsData[]
function KnownCardTracker:applyMoveDatas(moves)
  local player = self.player

  -- 本次移动时，对于主视角而言（UI上）可见的牌
  local visible_data = {} ---@type { [integer]: boolean }
  for _, move in ipairs(moves) do
    for _, info in ipairs(move.moveInfo) do
      local cid = info.cardId
      visible_data[cid] = player:cardVisible(cid, move)
    end
  end

  -- 将移动信息拆解成某个区域失去牌、某个区域得到牌，以及获得和牌堆相关移动中的移动方向
  local lose_infos, add_infos, drawpileDirection = self:splitMoveDatas(moves, visible_data)

  -- 将移动信息应用到记牌器的数据中
  for _, info in pairs(lose_infos) do
    self:trackLoseCards(info, drawpileDirection)
  end
  for _, info in pairs(add_infos) do
    self:trackAddCards(info, drawpileDirection)
  end
end

---@return KnownCards
function KnownCardTracker:getPlayerKnownCards(to, area, specialName)
  if type(to) == "number" then to = Fk:currentRoom():getPlayerById(to) end

  local t = self.player_cards[to.id] or {}
  if area == Player.Special then
    return t[specialName] or createKnownCards()
  else
    return t[area] or createKnownCards()
  end
end

---@param cardId integer
---@param player Player?
---@param area CardArea
---@param specialName string?
function KnownCardTracker:setCardKnown(cardId, player, area, specialName)
  local track = self:getKnownCardsByArea(area, player, specialName)
  local cids = Fk:currentRoom():getCardsByArea(area, player, false, specialName)

  if not table.contains(cids, cardId) then return end

  table.insertIfNeed(track.known_cards, cardId)
  table.removeOne(track.uncertain_cards, cardId)

  if #track.known_cards == #cids then
    track.uncertain_cards = {}
  end
end

return KnownCardTracker
