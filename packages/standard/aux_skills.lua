-- SPDX-License-Identifier: GPL-3.0-or-later

local discardSkill = fk.CreateActiveSkill{
  name = "discard_skill",
  card_filter = function(self, to_select, selected)
    if #selected >= self.num then
      return false
    end

    local checkpoint = true
    local card = Fk:getCardById(to_select)

    local status_skills = Fk:currentRoom().status_skills[ProhibitSkill] or {}
    for _, skill in ipairs(status_skills) do
      if skill:prohibitDiscard(Self, card) then
        return false
      end
    end

    if not self.include_equip then
      checkpoint = checkpoint and (Fk:currentRoom():getCardArea(to_select) ~= Player.Equip)
    end

    if self.pattern and self.pattern ~= "" then
      checkpoint = checkpoint and (Exppattern:Parse(self.pattern):match(card))
    end
    return checkpoint
  end,
  min_card_num = function(self) return self.min_num end,
  max_card_num = function(self) return self.num end,
}

local chooseCardsSkill = fk.CreateActiveSkill{
  name = "choose_cards_skill",
  expand_pile = function(self) return self.expand_pile end,
  card_filter = function(self, to_select, selected)
    if #selected >= self.num then
      return false
    end

    local checkpoint = true
    local card = Fk:getCardById(to_select)

    if not self.include_equip then
      checkpoint = checkpoint and (Fk:currentRoom():getCardArea(to_select) ~= Player.Equip)
    end

    if self.pattern and self.pattern ~= "" then
      checkpoint = checkpoint and (Exppattern:Parse(self.pattern):match(card))
    end
    return checkpoint
  end,
  min_card_num = function(self) return self.min_num end,
  max_card_num = function(self) return self.num end,
}

local choosePlayersSkill = fk.CreateActiveSkill{
  name = "choose_players_skill",
  card_filter = function(self, to_select)
    return self.pattern ~= "" and Exppattern:Parse(self.pattern):match(Fk:getCardById(to_select))
  end,
  target_filter = function(self, to_select, selected, cards)
    if self.pattern ~= "" and #cards == 0 then return end
    if #selected < self.num then
      return table.contains(self.targets, to_select)
    end
  end,
  card_num = function(self) return self.pattern ~= "" and 1 or 0 end,
  min_target_num = function(self) return self.min_num end,
  max_target_num = function(self) return self.num end,
}

local maxCardsSkill = fk.CreateMaxCardsSkill{
  name = "max_cards_skill",
  global = true,
  correct_func = function(self, player)
    return player:getMark("AddMaxCards") + player:getMark("AddMaxCards-turn") - player:getMark("MinusMaxCards") - player:getMark("MinusMaxCards-turn")
  end,
}

local moveTokenSkill = fk.CreateTriggerSkill{
  name = "move_token_skill",
  global = true,

  refresh_events = {fk.GameStart},  --refresh优先于on_use，不要在正常的游戏开始发牌技能refresh中拿牌
  can_refresh = function(self, event, target, player, data)
    return player.seat == 1
  end,
  on_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    local tokens = {}
    for _, id in ipairs(room.draw_pile) do
      if Fk:getCardById(id).name[1] == "&" then
        table.insertIfNeed(tokens, id)
      end
    end
    room:moveCards({
      ids = tokens,
      toArea = Card.Void,
      moveReason = fk.ReasonJustMove,
    })
  end,
}

AuxSkills = {
  discardSkill,
  chooseCardsSkill,
  choosePlayersSkill,
  maxCardsSkill,
  moveTokenSkill,
}
