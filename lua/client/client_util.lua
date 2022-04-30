-- All functions in this file are used by Qml

function Translate(src)
  return Fk.translations[src]
end

function GetGeneralData(name)
  local general = Fk.generals[name]
  if general == nil then general = Fk.generals["diaochan"] end
  return json.encode {
    kingdom = general.kingdom,
    hp = general.hp,
    maxHp = general.maxHp
  }
end

local cardSubtypeStrings = {
  [Card.SubtypeNone] = "none",
  [Card.SubtypeDelayedTrick] = "delayed_trick",
  [Card.SubtypeWeapon] = "weapon",
  [Card.SubtypeArmor] = "armor",
  [Card.SubtypeDefensiveRide] = "defensive_horse",
  [Card.SubtypeOffensiveRide] = "offensive_horse",
  [Card.SubtypeTreasure] = "treasure",
}

function GetCardData(id)
  local card = Fk.cards[id]
  if card == nil then return json.encode{
    cid = id,
    known = false
  } end
  local ret = {
    cid = id,
    name = card.name,
    number = card.number,
    suit = card:getSuitString(),
    color = card.color,
    subtype = cardSubtypeStrings[card.sub_type]
  }
  return json.encode(ret)
end

function GetAllGeneralPack()
  local ret = {}
  for _, name in ipairs(Fk.package_names) do
    if Fk.packages[name].type == Package.GeneralPack then
      table.insert(ret, name)
    end
  end
  return json.encode(ret)
end

function GetGenerals(pack_name)
  local ret = {}
  for _, g in ipairs(Fk.packages[pack_name].generals) do
    table.insert(ret, g.name)
  end
  return json.encode(ret)
end

function GetAllCardPack()
  local ret = {}
  for _, name in ipairs(Fk.package_names) do
    if Fk.packages[name].type == Package.CardPack then
      table.insert(ret, name)
    end
  end
  return json.encode(ret)
end

function GetCards(pack_name)
  local ret = {}
  for _, c in ipairs(Fk.packages[pack_name].cards) do
    table.insert(ret, c.id)
  end
  return json.encode(ret)
end

---@param card string | integer
---@param player integer
function CanUseCard(card, player)
  local c   ---@type Card
  if type(card) == "number" then
    c = Fk:getCardById(card)
  else
    error()
  end

  local ret = c.skill:canUse(ClientInstance:findPlayer(player))
  return json.encode(ret)
end

---@param card string | integer
---@param to_select integer @ id of the target
---@param selected integer[] @ ids of selected targets
---@param selected_cards integer[] @ ids of selected cards
function CanUseCardToTarget(card, to_select, selected)
  local c   ---@type Card
  local selected_cards
  if type(card) == "number" then
    c = Fk:getCardById(card)
    selected_cards = {card}
  else
    error()
  end

  local ret = c.skill:targetFilter(to_select, selected, selected_cards)
  return json.encode(ret)
end

---@param card string | integer
---@param to_select integer @ id of a card not selected
---@param selected integer[] @ ids of selected cards
---@param selected_targets integer[] @ ids of selected players
function CanSelectCardForSkill(card, to_select, selected_targets)
  local c   ---@type Card
  local selected_cards
  if type(card) == "number" then
    c = Fk:getCardById(card)
    selected_cards = {card}
  else
    error()
  end

  local ret = c.skill:cardFilter(to_select, selected_cards, selected_targets)
  return json.encode(ret)
end

---@param card string | integer
---@param selected integer[] @ ids of selected cards
---@param selected_targets integer[] @ ids of selected players
function CardFeasible(card, selected_targets)
  local c   ---@type Card
  local selected_cards
  if type(card) == "number" then
    c = Fk:getCardById(card)
    selected_cards = {card}
  else
    error()
  end

  local ret = c.skill:feasible(selected_cards, selected_targets)
  return json.encode(ret)
end
