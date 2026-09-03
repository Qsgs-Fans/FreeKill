-- SPDX-License-Identifier: GPL-3.0-or-later

---@class ActiveSkill : ButtonSkill
local ActiveSkill = ButtonSkill:subclass("ActiveSkill")

---------
-- 注：客户端函数，AI也会调用以作主动技判断
------- {

-- 判断该技能是否可主动发动
---@param player Player @ 使用者
---@param card? Card @ 牌，若该技能是卡牌的效果技能，需输入此值
---@param extra_data? UseExtraData @ 额外数据
---@return boolean?
function ActiveSkill:canUse(player, card, extra_data)
  return self:isEffectable(player) and self:withinTimesLimit(player, Player.HistoryPhase, card)
end

-- 获取选择时的固定目标。注意，不需要进行任何合法性判断
---@param player Player @ 使用者
---@param selected_cards integer[] @ 已选牌
---@param card? Card @ 牌
---@param extra_data? UseExtraData @ 额外数据
---@return Player[]? @ 返回固定目标角色列表。若此牌可以选择目标，返回空表
function ActiveSkill:fixTargets(player, selected_cards, card, extra_data)
  if self:getMaxTargetNum(player) == 0 then
    return {}
  end
  return nil
end

-- 技能的交互选项（如选项框、选项卡等）返回值self.interaction.data确定后，可使用这个预先进行一次修改
---@param player Player @ 使用者
---@param selected_targets Player[] @ 已选目标
---@param selected_cards integer[] @ 已选牌
function ActiveSkill:update_interaction(player, selected_cards, selected_targets)
  if self.interaction == nil then return end
  local spec = self.interaction.spec or {}
  if spec.type ~= "ToBeDecided" then return end

  local dat = self.interaction.data
  spec.UIrequest = table.simpleClone(dat)
  if dat.elemType == "OptionBox" then
    if dat.option == "Cancel" then
      --FIXME(邪道实现): 直接修改req来取消self.pendings选牌
      local handler = ClientInstance.current_request_handler
      if handler then
        handler.pendings = {}
      end
      spec.result = nil
    else
      spec.result = {}
      if dat.option ~= "OK" then
        spec.result.name = dat.option
      end
    end
  elseif dat.elemType == "ExpandItem" then
    spec.result = spec.result or {}
    if spec.result.name == dat.name then
      spec.result.name = nil
      spec.pendings = {}
    else
      spec.result.name = dat.name
      spec.pendings = { dat.cid }
    end
  end

  if spec.result and #selected_targets > 0 then
    self.interaction.data = nil
    --验证selected_targets的目标，如果能通过，则填充原目标
    local targets_copy = {}
    for _, p in ipairs(selected_targets) do
      if self:targetFilter(player, p, targets_copy, selected_cards) then
        table.insert(targets_copy, p)
      else
        break
      end
    end
    if #targets_copy == #selected_targets then
      spec.UIrequest.selected_targets = targets_copy
      --取消掉setup自带的自动选目标！
      dat.autoTarget = false
    end
  end

  self.interaction.data = (spec.result or {}).name
end

-- 刷新技能的交互选项（如选项框、选项卡等），返回一个表，表中每个元素为一个选项
---@param player Player @ 使用者
---@param selected_targets Player[] @ 已选目标
---@param selected_cards integer[] @ 已选牌
---@return table?
function ActiveSkill:refresh_interaction(player, selected_cards, selected_targets)
  if self.interaction == nil then return end
  local spec = self.interaction.spec or {}

  if spec.type == "optionbox" and spec.direct_send then
    if self:feasible(player, selected_targets, selected_cards) then
      return self.interaction.spec.options
    end
    return {}
  end

  if spec.type ~= "ToBeDecided" then return end

  local refresh_data = {}
  local req = spec.UIrequest or {}
  local tos = selected_targets

  if #tos == 0 and req.selected_targets and #req.selected_targets > 0 then
    --interaction.data变化会掉目标，要在这里补上
    --待定：update_interaction已进行过预验证，这里还有必要再判一圈合法性吗？
    local handler = ClientInstance.current_request_handler
    if handler then
      tos = spec.UIrequest.selected_targets
      for _, to in ipairs(tos) do
        handler:selectTarget(to.id, { selected = true })
      end
    end
  end

  local helper = self:interaction_helper(player, selected_cards, tos)
  if helper == nil then return end

  if helper.type == "cardname" then
    local max_num, min_num = self:getMaxCardNum(player), self:getMinCardNum(player)

    if spec.UIrequest == nil then
      if #selected_cards == max_num and spec.result == nil then
        spec.result = {}
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
        local names = helper.choices or {}
        for _, name in ipairs(helper.all_choices or names) do
          local card = Fk:cloneCard(name, Card.NoSuit, 0)
          table.insert(items, {
            prop = {
              type = "card",
              card = card,
              additional_prop = { selectable = table.contains(names, card.name) }
            },
            name = name,
            cid = i,
          })
          i = i + 1
        end
        refresh_data.expandItems = items
      end
    elseif req.elemType == "ExpandItem" then
      refresh_data.pendings = spec.pendings
    end

    if max_num > 0 then
      --可选牌时，需要重设手牌区按钮
      if spec.result == nil then
        if #selected_cards >= min_num then
          refresh_data.optionBox = UI.OptionBox { options = { "OK" } }
        end
      else
        local handler = ClientInstance.current_request_handler
        if handler and handler.class.name == "ReqActiveSkill" then
          --在读条中使用的情况直接使用自带的确定取消即可（因为可以反复操作）
          local op_spec = {   ---@class OptionBoxParams
            options = {},
            all_options = { "OK" },
            direct_send = true,
            cancelable = true
          }
          if self:feasible(player, tos, selected_cards) then
            op_spec.options = { "OK" }
          end
          refresh_data.optionBox = UI.OptionBox(op_spec)
        end
      end
    end
  elseif helper.type == "optionbox" then
    if self.interaction.data == nil then
      refresh_data.optionBox = helper
    else
      if req.elemType == "OptionBox" and self:feasible(player, tos, selected_cards) then
        --按下选项后，若满足feasible，则自动确认！
        local h = ClientInstance.current_request_handler
        if h then
          h:update("Button", "OK", "")
          h:_finish()
        end
        spec.UIrequest = nil
        return
      end

      local handler = ClientInstance.current_request_handler
      if handler and handler.class.name == "ReqActiveSkill" then
        --在读条中使用的情况直接使用自带的确定取消即可（因为可以反复操作）
        local op_spec = {   ---@class OptionBoxParams
          options = {},
          all_options = { "OK" },
          direct_send = true,
          cancelable = true
        }
        if self:feasible(player, tos, selected_cards) then
          op_spec.options = { "OK" }
        end
        refresh_data.optionBox = UI.OptionBox(op_spec)
      end
    end
  end

  spec.UIrequest = nil
  return refresh_data
end

------- }

return ActiveSkill
