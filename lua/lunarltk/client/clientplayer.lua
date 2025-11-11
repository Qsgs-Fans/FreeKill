-- SPDX-License-Identifier: GPL-3.0-or-later

---@class ClientPlayer: Player, ClientPlayerBase
local ClientPlayer = Player:subclass("ClientPlayer")
ClientPlayer:include(Fk.Base.ClientPlayerBase)

---@class ClientMarkData
---@field public visible boolean? @ 标记区域是否可见，默认可见

---@class ClientPlayer
---@field public next ClientPlayer
---@field public markArea ClientMarkData? @ 关于标记显示的一些事项

function ClientPlayer:initialize(cp)
  Player.initialize(self)
  Fk.Base.ClientPlayerBase.initialize(self, cp)
end

local function fillMoveData(card_moves, visible_data, self, area, specialName)
  local cards = self.player_cards
  local ids = cards[area]
  if specialName then ids = self.special_cards[specialName] end
  if #ids ~= 0 then
    for _, id in ipairs(ids) do
      visible_data[tostring(id)] = Self:cardVisible(id)
      Fk:filterCard(id, self)
    end
    local move = {
      ids = ids,
      to = self.id,
      fromArea = Card.DrawPile,
      toArea = area,
      specialName = specialName,
    }
    table.insert(card_moves, move)
  end
end

-- 仅用于断线重连或者旁观时：将数据同步到qml界面中
function ClientPlayer:sendDataToUI()
  local c = ClientInstance --[[@as Client]]
  local id = self.id
  for _, k in ipairs(self.property_keys) do
    c:notifyUI("PropertyUpdate", { id, k, self[k] })
  end

  local card_moves = {}
  local visible_data = {}
  for _, area in ipairs { Player.Hand, Player.Equip, Player.Judge } do
    fillMoveData(card_moves, visible_data, self, area)
  end
  for name in pairs(self.special_cards) do
    fillMoveData(card_moves, visible_data, self, Card.PlayerSpecial, name)
  end
  if #card_moves > 0 then
    visible_data.merged = card_moves
    visible_data.event_id = 0
    c:notifyUI("MoveCards", visible_data)
  end

  for mark, value in pairs(self.mark) do
    if mark[1] == "@" then
      if mark:startsWith("@[") and mark:find(']') then
        local close = mark:find(']')
        local mtype = mark:sub(3, close - 1)
        local spec = Fk.qml_marks[mtype]
        if spec then
          local text = spec.how_to_show(mark, value, self)
          if text == "#hidden" then value = 0 end
        end
      end
      c:notifyUI("SetPlayerMark", { id, mark, value })
    end
  end

  for _, skill in ipairs(self.player_skills) do
    if skill.visible then
      c:notifyUI("AddSkill", { id, skill.name })
    end
  end

  for k, v in pairs(self.skillUsedHistory) do
    if v[4] > 0 then
      c:setSkillUseHistory({ id, k, v[1], 1 })
      c:setSkillUseHistory({ id, k, v[2], 2 })
      c:setSkillUseHistory({ id, k, v[3], 3 })
      c:setSkillUseHistory({ id, k, v[4], 4 })
    end
  end
end

return ClientPlayer
