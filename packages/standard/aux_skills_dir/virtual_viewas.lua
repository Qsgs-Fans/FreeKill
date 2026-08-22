local virtual_viewas = fk.CreateSkill{
  name = "virtual_viewas",
}

virtual_viewas:addEffect("viewas", {
  expand_pile = function(self, player)
    if #self.subcards > 0 then
      return {}
    elseif self.card_filter.n[1] > 0 then
      return table.filter(self.card_filter.cards, function(id)
        return not table.contains(player:getCardIds("he"), id)
      end)
    end
    return {}
  end,
  card_filter = function(self, player, to_select, selected)
    if #self.subcards > 0 then
      return false
    else
      local exp = Exppattern:Parse(self.card_filter.pattern)
      return #selected < self.card_filter.n[2] and table.contains(self.card_filter.cards, to_select) and
        exp:match(Fk:getCardById(to_select))
    end
  end,
  interaction = UI.ToBeDecided {},
  update_interaction = function(self, player, selected_cards, selected_targets, extra_data)
    if #self.all_choices == 1 and not self.namebox then return end
    local dat = self.interaction.data
    self.interaction.spec.UIrequest = table.simpleClone(dat)
    if dat.elemType == "OptionBox" then
      if dat.option == "Cancel" then
        --FIXME(邪道实现): 直接修改req来取消self.pendings选牌
        local handler = ClientInstance.current_request_handler
        if handler then
          handler.pendings = {}
        end
        self.interaction.spec.result = nil
      else
        self.interaction.spec.result = { cards = table.simpleClone(selected_cards) }
      end
    elseif dat.elemType == "ExpandItem" then
      self.interaction.spec.result = self.interaction.spec.result or {}
      if self.interaction.spec.result.name == dat.name then
        self.interaction.spec.result.name = nil
        self.interaction.spec.pendings = {}
      else
        self.interaction.spec.result.name = dat.name
        self.interaction.spec.pendings = { dat.cid }
      end
    end
    self.interaction.data = (self.interaction.spec.result or {}).name
  end,
  refresh_interaction = function(self, player, selected_cards, selected_targets, extra_data)
    if #self.all_choices == 1 and not self.namebox then return end
    local refresh_data = {}
    local req = self.interaction.spec.UIrequest or {}

    local cardFilter = self.card_filter

    if self.interaction.spec.UIrequest == nil then
      if #selected_cards == cardFilter.n[2] and self.interaction.spec.result == nil then
        self.interaction.spec.result = { cards = table.simpleClone(selected_cards) }
        req = {
          elemType = "OptionBox",
          option = "OK"
        }
      end
    end

    if req.elemType == "OptionBox" then
      if req.option == "Cancel" then
        --回归选牌步骤
        refresh_data.expandItems = {}
      else
        local items = {}
        local i = 1
        local subcards = self.subcards
        if #subcards == 0 then
          subcards = cardFilter.fake_subcards and {} or self.interaction.spec.result.cards
        end
        for _, name in ipairs(self.all_choices) do
          local card = Fk:cloneCard(name, nil, nil, self.skillName, subcards)
          table.insert(items, {
            prop = {
              type = "card",
              card = card,
              additional_prop = { selectable = (table.contains(self.choices, name) and player:canUseOrResponseInCurrent(card)) }
            },
            name = name,
            cid = i,
          })
          i = i + 1
        end
        refresh_data.expandItems = items
      end
    elseif req.elemType == "ExpandItem" then
      refresh_data.pendings = self.interaction.spec.pendings
    end

    if cardFilter.n[2] > 0 then
      --可选牌时，需要重设手牌区按钮
      if self.interaction.spec.result == nil then
        local spec = {   ---@class OptionBoxParams
          options = {},
          all_options = { "OK" }
        }
        if #selected_cards >= cardFilter.n[1] then
          spec.options = { "OK" }
        end
        refresh_data.optionBox = UI.OptionBox(spec)
      else
        local spec = {   ---@class OptionBoxParams
          options = {},
          all_options = { "OK" },
          direct_send = true,
          cancelable = true
        }
        local card = self:viewAs(player, selected_cards)
        if card and card:getSkill(player):feasible(player, selected_targets, { }, card) then
          spec.options = { "OK" }
        end
        refresh_data.optionBox = UI.OptionBox(spec)
      end
    end
    self.interaction.spec.UIrequest = nil
    return refresh_data
  end,
  view_as = function(self, player, cards)
    local name = (#self.all_choices == 1 and not self.namebox and self.all_choices[1]) or self.interaction.data
    if Fk.all_card_types[name] == nil then return nil end
    local card = Fk:cloneCard(name)
    if self.skillName then
      card.skillName = self.skillName
    end
    if #self.subcards > 0 then
      card:addSubcards(self.subcards)
    else
      if #cards < self.card_filter.n[1] or #cards > self.card_filter.n[2] then return end
      if #cards > 0 then
        if self.card_filter.fake_subcards then
          card:addFakeSubcards(cards)
        else
          card:addSubcards(cards)
        end
      end
    end
    return card
  end,
})

virtual_viewas:addAI(nil, "vs_skill")

return virtual_viewas
