local RoomScene = require 'ui_emu.roomscene'
local Interaction = require 'ui_emu.interaction'
local CardItem = (require 'ui_emu.common').CardItem

--[[
  负责处理AskForUseActiveSkill的Handler。
  涉及的UI组件：手牌区内的牌（TODO：expand牌）、在场角色、确定取消按钮
                （TODO：interaction小组件）
  可能发生的事件：
  * 点击手牌：刷新所有未选中牌的enable
  * 点击角色：刷新所有未选中的角色
  * (TODO) 修改interaction：重置信息
  * 按下按钮：发送答复

  为了后续的复用性需将ViewAsSkill也考虑进去
--]]

---@class ReqActiveSkill: RequestHandler
---@field public skill_name string 当前响应的技能名
---@field public prompt string 提示信息
---@field public cancelable boolean 可否取消
---@field public extra_data UseExtraData|table 传入的额外信息
---@field public pendings integer[] 正在选择的卡牌id数组
---@field public selected_buffer? { cards: integer[], targets: integer[], interaction: any } 上次选择的缓存，用于二级选择时恢复
---@field public sub_cards? Card[] 二级选择时的全体卡牌对象数组
---@field public sub_pendings Card[] 二级选择时的卡牌**本体**数组
---@field public sub_selection_flag boolean 是否是子选择（例如泛印牌的二级选择）
---@field public selected_targets integer[] 选择的目标
---@field public expanded_piles { [string]: integer[] } 用于展开/收起
---@field public visible_pile integer[]
---@field public original_prompt string 最开始的提示信息；这种涉及技能按钮的需要这样一下
local ReqActiveSkill = RequestHandler:subclass("ReqActiveSkill")

function ReqActiveSkill:initialize(player, data)
  RequestHandler.initialize(self, player)
  self.scene = RoomScene:new(self)

  self.expanded_piles = {}
  self.sub_selection_flag = false

  if data then
    self.skill_name = data[1]
    self.prompt     = data[2]
    self.cancelable = data[3]
    self.extra_data = data[4]

    if type(self.skill_name) == "string" and self.skill_name ~= "" then
      self.original_prompt = ("#UseSkill:::" .. self.skill_name)
    end
  end
end

--- 自动选择唯一目标
---@param req ReqActiveSkill
local function autoSelectOnlyFeasibleTarget(req, data)
  if data.autoTarget and not req:feasible() then
    local tars = {}
    for _, to in ipairs(req.room.alive_players) do
      if req:targetValidity(to.id) then
        table.insert(tars, to.id)
        if #tars > 1 then return end
      end
    end
    if #tars == 1 then
      req.selected_targets = tars
      req.scene:update("Photo", tars[1], { selected = true })
      req:updateUnselectedTargets()
      req:updateButtons()
    end
  end
end

--- 初始化所有信息
---@param ignoreInteraction? boolean @ 是否不初始化Interaction，继承原数据
---@param data? table @ 出牌阶段发动的技能需要主动传入是否自动选择
function ReqActiveSkill:setup(ignoreInteraction, data)
  local scene = self.scene

  local old_pendings = table.simpleClone(self.pendings or {})
  self.pendings = {}
  self.selected_targets = {}

  if Fk.skills[self.skill_name] and Fk.skills[self.skill_name].click_count then
    self.player:addSkillUseHistory(self.skill_name, 1)
    if ClientInstance then
      ClientInstance:notifyUI("LogEvent", {
        type = "PlaySkillSound",
        name = self.skill_name,
        i = -1,
        general = self.player.general,
        deputy = self.player.deputyGeneral,
      })
    end
  end

  if self.sub_selection_flag then
    scene:removeItem("Interaction", "1") -- 这里不考虑interaction
  else
    self.sub_cards = nil
    self.sub_pendings = {}
    -- FIXME: 偷懒了，让修改interaction时的全局刷新功能复用setup 总之这里写的很垃圾
    if not ignoreInteraction then
      scene:removeItem("Interaction", "1")
      self:setupInteraction()
    end
  end

  self:setPrompt(self.prompt)

  self:retractAllPiles()
  self:expandPiles()

  scene:unselectAllCards()
  scene:unselectAllTargets()

  self:updateUnselectedCards()
  self:updateUnselectedTargets()

  self:visualizePile()

  if ignoreInteraction and #(self.visible_pile or {}) == 0 then -- 修改Interaction时重新筛选一次原选择牌
    for _, cid in ipairs(old_pendings) do
      local item -- 必须确定此牌是否还在UI内
      for _cid, _item in pairs(scene:getAllItems("CardItem")) do
        if _cid == cid then
          item = _item
          break
        end
      end
      if item and self:cardValidity(cid) then -- 直接调用封装模拟选牌，这下不能出错了吧？
        self:selectCard(cid, { selected = true })
        self:initiateTargets()
      end
    end
  end

  if data then
    autoSelectOnlyFeasibleTarget(self, data)
  end

  self:refreshInteraction()
  self:updateButtons()
  self:updatePrompt()
end

local function getCardByVirtId(cards, id)
  return table.find(cards, function(c) return c.id == id or c.virt_id == id end)
end

function ReqActiveSkill:finish()
  self:retractAllPiles()
end

--- 更新主动技的提示（使用卡牌也会走这步）
---@param skill ButtonSkill @ 技能对象
---@param selected_cards? integer[] @ 选择的牌
function ReqActiveSkill:setSkillPrompt(skill, selected_cards)
  local default_prompt = ("#UseSkill:::" .. skill.name) -- 默认提示
  local prompt = ""
  if self.sub_selection_flag then
    if type(skill.sub_prompt) == "function" then
      prompt = skill:sub_prompt(self.player,
        self.selected_buffer.cards, table.map(self.selected_buffer.targets, Util.Id2PlayerMapper),
        self.sub_pendings, table.map(self.selected_buffer.targets or {}, Util.Id2PlayerMapper),
        self.extra_data or {})
    elseif type(skill.sub_prompt) == "string" then
      prompt = skill.sub_prompt
    end
  end
  if prompt == "" then
    if type(skill.prompt) == "function" then
      prompt = skill:prompt(self.player, selected_cards or self.pendings,
        table.map(self.selected_targets, Util.Id2PlayerMapper), self.extra_data or {})
    elseif type(skill.prompt) == "string" then
      prompt = skill.prompt
    end
  end

  -- 被动询问使用主动技时，例如询问弃牌，求询问使用牌
  -- 这一步判定不能少，因为出牌阶段用牌也会走这步，不应锁定为self.prompt
  if self.extra_data then
    if prompt == "" and type(self.prompt) == "string" then
      prompt = self.prompt
    end
  end
  self:setPrompt(prompt == "" and default_prompt or prompt)
  --- 千万不能设置为self.original_prompt！！！！！！！！！！！！
end

function ReqActiveSkill:updatePrompt()
  local skill = Fk.skills[self.skill_name] --[[@as ButtonSkill]]
  if skill then
    self:setSkillPrompt(skill)
  else
    self:setPrompt(self.original_prompt or "")
  end
end

--- 初始化Interaction
function ReqActiveSkill:setupInteraction()
  local skill = Fk.skills[self.skill_name] --[[@as ButtonSkill]]
  if skill and skill.interaction then
    skill.interaction.data = nil
    local interaction = skill:interaction(self.player)
    if not interaction then
      return
    end
    skill.interaction.data = interaction.default or interaction.default_choice or nil -- FIXME
    -- 假设只有1个interaction （其实目前就是这样）
    skill.interaction.spec = table.simpleClone(interaction)
    local i = Interaction:new(self.scene, "1", interaction)
    i.skill_name = interaction.skill_name or self.skill_name
    self.scene:addItem(i)
  end
end


--- 在手牌区展开一些牌，注可以和已有的牌重复
---@param pile string @ 牌堆名，用于标识
---@param extra_ids? integer[]|Card[] @ 额外的牌id数组
---@param extra_footnote? string @ 卡牌底注
---@return integer[] @ 展开的牌id数组
function ReqActiveSkill:expandPile(pile, extra_ids, extra_footnote)
  if pile ~= "_extra" and self.expanded_piles[pile] ~= nil then return {} end
  local ids, footnote
  local player = self.player

  if pile == "_equip" then
    ids = player:getCardIds("e")
    footnote = "$Equip"
  elseif pile == "_extra" and extra_ids then
    -- expand_pile为id表的情况
    ids = extra_ids
    footnote = extra_footnote
    -- self.extra_cards = exira_ids
    self.expanded_piles[pile] = self.expanded_piles[pile] or {}
    table.insertTable(self.expanded_piles[pile], ids)
  elseif pile == "_sub_selection" and extra_ids then
    -- 二级菜单的expand_pile必为实体卡牌表……
    self.expanded_piles["_sub_selection"] = table.map(extra_ids, function(c) return Fk:currentRoom():getVirtCardId(c) end)
    ids = extra_ids
    footnote = self.skill_name -- 只写一个技能名
  else
    -- expand_pile为私人牌堆名的情况
    -- FIXME: 可能存在的浅拷贝
    ids = extra_ids or table.simpleClone(player:getPile(pile))
    footnote = extra_footnote or pile
  end

  self.expanded_piles[pile] = self.expanded_piles[pile] or ids

  local scene = self.scene
  for _, id in ipairs(ids) do
    scene:addItem(CardItem:new(scene, id), {
      reason = "expand",
      footnote = footnote,
    })
  end
  return ids
end

function ReqActiveSkill:retractPile(pile)
  if self.expanded_piles[pile] == nil then return end
  local ids = self.expanded_piles[pile]
  self.expanded_piles[pile] = nil

  local scene = self.scene
  for _, id in ipairs(ids) do
    scene:removeItem("CardItem", id, {
      reason = "retract",
      footnote = pile == "_equip" and "$Equip" or pile -- FIXME: 有的pile使用extra_footnote，当然装备区不影响
    })
  end
end

function ReqActiveSkill:retractAllPiles()
  for k, v in pairs(self.expanded_piles) do
    self:retractPile(k)
  end
end

-- 展开额外牌堆（即将所有不在手牌区的牌在手牌区域展开）
function ReqActiveSkill:expandPiles()
  local skill = Fk.skills[self.skill_name] --[[@as ButtonSkill]]
  local player = self.player
  if not skill then return end

  -- 二级菜单无视一切展开额外牌堆
  if self.sub_selection_flag then
    self:expandPile("_sub_selection", self.sub_cards)
    return
  end

  -- TODO: 为了缔盟的无奈之法，应该多次判定是否展开
  local expand_equip = skill.include_equip
  -- 展开自己装备区
  -- 特殊：equips至少有一张能亮着的情况下才展开 且无视是否存在skill.expand_pile
  if not expand_equip then
    for _, id in ipairs(player:getCardIds("e")) do
      if self:cardValidity(id) then
        expand_equip = true
        break
      end
    end
  end
  if expand_equip then
    self:expandPile("_equip")
  end

  -- 记录已展开的牌，防止重复展开
  local cardsExpanded = player:getCardIds("he") -- 禁止展开自己手牌、装备区

  -- 如果可以调用如手牌般使用的牌，也展开
  if skill.handly_pile then
    for pile in pairs(player.special_cards) do
      if pile:endsWith('&') then
        self:expandPile(pile)
      end
    end

    local filterSkills = Fk:currentRoom().status_skills[FilterSkill] or Util.DummyTable ---@type FilterSkill[]
    for _, filter in ipairs(filterSkills) do
      local ids = filter:handlyCardsFilter(player)
      if ids then
        ids = table.filter(ids, function(id) return not table.contains(cardsExpanded, id) end)
        if #ids > 0 then
          self:expandPile(filter.name, ids)
          table.insertTable(cardsExpanded, ids)
        end
      end
    end
  end

  -- 展开该技能本身的额外牌堆
  local pile = skill.expand_pile
  local ids
  if type(pile) == "function" then
    ids = table.filter(pile(skill, player), function(id) return not table.contains(cardsExpanded, id) end)
  elseif type(pile) == "string" then
    self:expandPile(pile, player:getPile(pile), self.extra_data and self.extra_data.skillName)
  elseif type(pile) == "table" then
    ids = table.filter(pile, function(id) return not table.contains(cardsExpanded, id) end)
  end
  if ids == nil or next(ids) == nil then return end
  local room = Fk:currentRoom()
  local areas = {
    [Card.DrawPile] = "pile_draw",
    [Card.Processing] = "processing_area",
    [Card.DiscardPile] = "pile_discard"
  }
  local area
  for _, id in ipairs(ids) do
    if area == nil then
      area = room.card_place[id]
      if areas[area] == nil then break end
    elseif area ~= room.card_place[id] then
      area = nil
      break
    end
  end
  if areas[area] then
    self:expandPile("_extra", ids, areas[area])
  else
    local owner_pile, owners = {}, {}
    for _, id in ipairs(ids) do
      local owner = room:getCardOwner(id)
      local owner_key = owner and owner:toLogString() or ""
      owner_pile[owner_key] = table.insertIfNeed(owners, owner_key) and {} or owner_pile[owner_key]
      table.insert(owner_pile[owner_key], id)
    end
    for _, owner_key in ipairs(owners) do
      self:expandPile("_extra", owner_pile[owner_key], owner_key ~= "" and owner_key or
        (self.extra_data and self.extra_data.skillName or self.skill_name))
    end
  end
end

--- 刷新一下当前可见牌
function ReqActiveSkill:visualizePile()
  local skill = Fk.skills[self.skill_name] --[[@as ButtonSkill]]
  if not skill then return end
  local player = self.player

  -- 因为visible_pile是纯ui方案，与操作合法性无关，故不需要scene参与，直接改RequestHandler.change
  self.change = self.change or {}

  -- 直接在这里进行屏蔽手牌操作
  if self.sub_selection_flag then
    local room = Fk:currentRoom();
    self.change["visible_cards"] = table.map(self.sub_cards, function(c) return room:getVirtCardId(c) end) -- 二级选择时visible_pile改为二级选择牌堆
    return
  end

  local pile = skill.visible_pile or {}
  local _pile
  if type(pile) == "function" then
    _pile = pile(skill, player)
  else
    _pile = pile
  end
  if type(_pile) == "table" then
    self.visible_pile = _pile
  elseif type(_pile) == "string" then
    if _pile == "_expand_pile" then
      self.visible_pile = self.expanded_piles["_extra"] or {}
    else
      self.visible_pile = player:getPile(_pile)
    end
  else
    self.visible_pile = {}
  end

  self.change["visible_cards"] = self.visible_pile
end

--- 判断确认键是否可用
---@return boolean
function ReqActiveSkill:feasible()
  local player = self.player
  local skill = Fk.skills[self.skill_name] --[[@as ButtonSkill]]
  if not skill then return false end
  local card -- 因为有多种情况，所以需要缓存
  local ret = false
  local targets = table.map(self.selected_targets, Util.Id2PlayerMapper)
  if skill:isInstanceOf(ActiveSkill) then
    ---@cast skill ActiveSkill
    ret = skill:feasible(player, targets, self.pendings)
  elseif skill:isInstanceOf(ViewAsSkill) then
    ---@cast skill ViewAsSkill
    card = self:getUsingCard()
    if card then
      ret = card:getSkill(player):feasible(player, targets, { card.id }, card)
    elseif not self.sub_selection_flag then -- 如果是二级选择的场合就全权交给viewAs处理了
      ret = self.sub_cards and skill:feasible(player, targets, self.pendings) -- 因为生成函数，sub_cards可能为空，但若为数组则一定有元素
    end
  end
  return not not ret
end

function ReqActiveSkill:isCancelable()
  return self.sub_selection_flag or not not self.cancelable
end

--- 获得视为技所视为的虚拟牌
---@return Card|nil
function ReqActiveSkill:getUsingCard()
  local skill = Fk.skills[self.skill_name] --[[@as ButtonSkill]]
  if not (skill and skill:isInstanceOf(ViewAsSkill)) then return nil end
  if self.sub_selection_flag then
    return skill:viewAs(self.player, self.selected_buffer.cards, self.sub_pendings)
  else
    return skill:viewAs(self.player, self.pendings)
  end
end

--- 判断一张牌是否能被主动技或转化技点亮（注，使用实体牌不用此函数判断
---@param cid integer @ 待选卡牌id
---@return boolean
function ReqActiveSkill:cardValidity(cid)
  local skill = Fk.skills[self.skill_name] --[[@as ButtonSkill]]
  if not skill then return false end
  if self.sub_selection_flag then -- 二级选择时单独考虑
    if not getCardByVirtId(self.sub_cards, cid) then return false end -- 只能选择二级选择的牌
    return not not skill:subCardFilter(self.player, getCardByVirtId(self.sub_cards, cid), self.sub_pendings, self.selected_buffer.cards, self.extra_data)
  end
  return not not skill:cardFilter(self.player, cid, self.pendings or {}, table.map(self.selected_targets or {}, Util.Id2PlayerMapper))
end

--- 判断一个角色是否能被主动技或转化技点亮
---@param pid integer @ 待选角色id
---@return boolean
function ReqActiveSkill:targetValidity(pid)
  local skill = Fk.skills[self.skill_name] --[[@as ButtonSkill]]
  if not skill then return false end
  local card -- 因为有多种情况，所以需要缓存
  if skill:isInstanceOf(ViewAsSkill) then
    ---@cast skill ViewAsSkill
    card = self:getUsingCard()
    if card then
      skill = card:getSkill(self.player)
    else
      local sub_data = type(skill.sub_data) == "function" and skill:sub_data(self.player, self.pendings) or skill.sub_data
      if sub_data then
        return false -- 需要二级选择的技能，暂时不考虑targetFilter
      end
    end
  end
  local room = Fk:currentRoom()
  local p = room:getPlayerById(pid)
  local selected = table.map(self.selected_targets, Util.Id2PlayerMapper)
  return not not skill:targetFilter(self.player, p, selected, self.pendings, card, self.extra_data)
end

-- 获得二级选择的卡牌
function ReqActiveSkill:makeSubCards()
  self.sub_cards = nil
  local skill = Fk.skills[self.skill_name] --[[@as ButtonSkill]]
  if not skill or not skill.sub_data then return end
  local sub = skill.sub_data
  if type(sub) == "function" then
    self.sub_cards = sub(skill, self.player, self.pendings, skill.interaction and skill.interaction.data)
  else
    self.sub_cards = {}
    for _, card_name in ipairs(sub) do
      if Fk.all_card_types[card_name] ~= nil then
        table.insertIfNeed(self.sub_cards, Fk:cloneCard(card_name))
      end
    end
  end
  if self.sub_cards == nil or not next(self.sub_cards) then return end
end

--- 更新按钮的状态
function ReqActiveSkill:updateButtons()
  local scene = self.scene

  local isOk = self:feasible()
  if isOk and not self.sub_selection_flag then
    self:makeSubCards() -- 生成二级选择的卡牌
    if self.sub_cards then
      local skill = Fk.skills[self.skill_name] --[[@as ButtonSkill]]
      if skill and skill.immediate_sub then
        self.change = self.change or {} -- 移除_new/_delete的状态，毕竟马上就要重新收牌堆了
        self.change._new = nil
        self.change._delete = nil
        self:doOKButton()
      end
    end
  end
  scene:update("Button", "OK", { enabled = self:feasible() })
  scene:update("Button", "Cancel", { enabled = self:isCancelable() })
end

--- 更新未选择的卡牌的可选性
function ReqActiveSkill:updateUnselectedCards()
  local scene = self.scene

  for cid, item in pairs(scene:getAllItems("CardItem")) do
    if not item.selected then
      scene:update("CardItem", cid, { enabled = self:cardValidity(cid) })
    end
  end
end

--- 更新未选中的角色的enable属性
function ReqActiveSkill:updateUnselectedTargets()
  local scene = self.scene

  for pid, item in pairs(scene:getAllItems("Photo")) do
    if not item.selected then
      scene:updateTargetEnability(pid, self:targetValidity(pid))
    end
  end

  local player = self.player
  local target_fixed = true

  if self.skill_name then
    local skill = Fk.skills[self.skill_name] --[[@as ButtonSkill]]
    target_fixed = not not skill:fixTargets(player, self.pendings, nil, self.extra_data)
  end

  scene:updateTargetState(target_fixed)
end

--- 调整选牌后，随之调整目标
function ReqActiveSkill:initiateTargets()
  local room = self.room
  local scene = self.scene
  local skill = Fk.skills[self.skill_name]

  local old_targets = table.simpleClone(self.selected_targets)
  self.selected_targets = {}
  scene:unselectAllTargets()
  if skill then
    -- 筛选老目标合法性，如果有合法的再塞回已选
    for _, pid in ipairs(old_targets) do
      local ret = not not self:targetValidity(pid)
      if ret then table.insert(self.selected_targets, pid) end
      scene:update("Photo", pid, { selected = ret })
    end
    self:updateUnselectedTargets()
  else
    scene:disableAllTargets()
  end
  self:updateButtons()
end

--- 更新interaction数据
function ReqActiveSkill:updateInteraction(data, ignoreSetup)
  local skill = Fk.skills[self.skill_name] --[[@as ButtonSkill]]
  if skill and skill.interaction then
    skill.interaction.data = data
    --self.scene:update("Interaction", "1", { data = data })
    if skill.update_interaction then
      skill:update_interaction(
        self.player, self.pendings or {},
        table.map(self.selected_targets,
        Util.Id2PlayerMapper),
        self.extra_data or {}
      )
    end
    if not ignoreSetup then
      ReqActiveSkill.setup(self, true, type(data) == "table" and data) -- interaction变动后需复原
    end
  end
end

---@class ReplyFormatActive: table
---@field public card_objs? Card[] @ 选中的虚拟牌对象数组
---@field public card { skill: string, subcards: integer[] } @ 选中的牌信息
---@field public targets integer[] @ 选中的目标id数组
---@field public interaction_data? any @ 选中的interaction数据
---@field public special_skill? string @ 选中的技能名（如重铸）

function ReqActiveSkill:doOKButton()
  local skill = Fk.skills[self.skill_name] --[[@as ButtonSkill]]
  local cardstr = {
    skill = self.skill_name,
    subcards = self.pendings
  }
  local reply
  if self.sub_selection_flag then
    cardstr.subcards = self.selected_buffer.cards
    reply = {
      card_objs = self.sub_pendings,
      card = cardstr,
      targets = self.selected_targets or {},
      --special_skill = roomScene.getCurrentCardUseMethod(),
      interaction_data = skill and skill.interaction and skill.interaction.data,
    }
    if self.selected_card then
      reply.special_skill = self.skill_name
    end
  else
    if skill.sub_data then
      self.selected_buffer = {
        cards = table.simpleClone(self.pendings),
        targets = table.simpleClone(self.selected_targets),
        interaction = skill and skill.interaction and skill.interaction.data,
      }
      local sub = skill.sub_data
      if type(sub) == "function" then
        self.sub_cards = sub(skill, self.player, self.pendings, skill.interaction and skill.interaction.data)
      else
        self.sub_cards = {}
        for _, card_name in ipairs(sub) do
          if Fk.all_card_types[card_name] ~= nil then
            table.insertIfNeed(self.sub_cards, Fk:cloneCard(card_name))
          end
        end
      end
      table.forEach(self.sub_cards, function(c) Fk:currentRoom():getVirtCardId(c) end)
      self.sub_selection_flag = true
      self:setup(true) -- 需复原
    else
      reply = {
        card = cardstr,
        targets = self.selected_targets or {},
        --special_skill = roomScene.getCurrentCardUseMethod(),
        interaction_data = skill and skill.interaction and skill.interaction.data,
      }
      if self.selected_card then
        reply.special_skill = self.skill_name
      end
    end
  end
  if reply and ClientInstance then
    ClientInstance:notifyUI("ReplyToServer", reply)
  else
    return reply
  end
end

function ReqActiveSkill:doCancelButton()
  if self.sub_selection_flag then
    self.sub_selection_flag = false
    self:setup(true) -- 需复原
    return
  end
  if ClientInstance then
    ClientInstance:notifyUI("ReplyToServer", "__cancel")
  else
    return "__cancel"
  end
end

-- 对点击卡牌的处理。data中包含selected属性，可能是选中或者取消选中，分开考虑。
function ReqActiveSkill:selectCard(cardid, data)
  local scene = self.scene
  local selected = data.selected
  scene:update("CardItem", cardid, data)

  if self.sub_selection_flag then
    -- 二级菜单选的是虚拟牌
    if selected then
      table.insertIfNeed(self.sub_pendings, getCardByVirtId(self.sub_cards, cardid))
      table.insertIfNeed(self.pendings, cardid)
    else
      local old_pendings = table.simpleClone(self.pendings)
      self.pendings = {}
      self.sub_pendings = {}
      for _, cid in ipairs(old_pendings) do
        local ret = cid ~= cardid and self:cardValidity(cid)
        if ret then
          table.insertIfNeed(self.sub_pendings, getCardByVirtId(self.sub_cards, cid))
          table.insert(self.pendings, cid)
        end
        -- 因为这里而变成未选中的牌稍后将更新一次enable 但是存在着冗余的cardFilter调用
        scene:update("CardItem", cid, { selected = not not ret })
      end
    end
  else
    -- 若选中，则加入已选列表；若取消选中，则其他牌可能无法满足可选条件，需额外判断
    -- 例如周善 选择包括“安”在内的任意张手牌交出
    if selected then
      table.insert(self.pendings, cardid)
    else
      local old_pendings = table.simpleClone(self.pendings)
      self.pendings = {}
      for _, cid in ipairs(old_pendings) do
        local ret = cid ~= cardid and self:cardValidity(cid)
        if ret then table.insert(self.pendings, cid) end
        -- 因为这里而变成未选中的牌稍后将更新一次enable 但是存在着冗余的cardFilter调用
        scene:update("CardItem", cid, { selected = not not ret })
      end
    end
  end

  -- 最后刷新未选牌的enable属性
  self:updateUnselectedCards()
end

-- 对点击角色的处理。data中包含selected属性，可能是选中或者取消选中。
---@param playerid integer
---@param data table
function ReqActiveSkill:selectTarget(playerid, data)
  local scene = self.scene
  local selected = data.selected
  local skill = Fk.skills[self.skill_name]
  scene:update("Photo", playerid, data)

  -- 类似选卡
  -- 增加目标时，直接塞入已选目标组即可
  if selected then
    table.insert(self.selected_targets, playerid)
  else
    -- 减少目标时，先取消所有目标
    local old_targets = table.simpleClone(self.selected_targets)
    self.selected_targets = {}
    scene:unselectAllTargets()
    -- 再挨个判定原目标，若（除被取消的目标外的）原目标依旧合法，则塞入已选目标
    for _, pid in ipairs(old_targets) do
      local ret = pid ~= playerid and self:targetValidity(pid)
      if ret then -- 如果此目标合法，则塞入已选，且不允许再选中
        table.insert(self.selected_targets, pid)
      end
      scene:update("Photo", pid, { selected = not not ret })
    end
  end

  self:updateUnselectedTargets()
  -- 重新筛选原原卡合法性
  local old_pendings = table.simpleClone(self.pendings)
  self.pendings = {}
  if self.sub_selection_flag then
    self.sub_pendings = {}
    for _, cid in ipairs(old_pendings) do
        local ret = self:cardValidity(cid)
        if ret then
          table.insertIfNeed(self.sub_pendings, getCardByVirtId(self.sub_cards, cid))
          table.insert(self.pendings, cid)
        end
    end
  else
    for _, cid in ipairs(old_pendings) do
      local ret = self:cardValidity(cid)
      if ret then table.insert(self.pendings, cid) end
      scene:update("CardItem", cid, { selected = not not ret })
    end
  end
  self:updateUnselectedCards()
  self:updateButtons()
end

-- 刷新interaction（不是重新加载，区别于updateInteraction）
function ReqActiveSkill:refreshInteraction()
  local skill = Fk.skills[self.skill_name] --[[@as ButtonSkill]]
  if not skill or not skill.refresh_interaction then return end
  if skill and skill.interaction then
    local refresh_data = skill:refresh_interaction(
      self.player, self.pendings or {},
      table.map(self.selected_targets,
      Util.Id2PlayerMapper),
      self.extra_data or {})
    if refresh_data ~= nil then
      self.scene:update("Interaction", "1", { refresh_data = refresh_data })
    end
  end
end

function ReqActiveSkill:update(elemType, id, action, data)
  if elemType == "Button" then
    local ret = false
    if id == "OK" then ret = not not self:doOKButton()
    elseif id == "Cancel" then ret = not not self:doCancelButton() end
    return ret
  elseif elemType == "CardItem" then
    self:selectCard(id, data)
    self:initiateTargets()
    autoSelectOnlyFeasibleTarget(self, data)
    -- 双击卡牌使用卡牌
    --[[
    if action == "doubleClick" and data.doubleClickUse then
      if not data.selected then -- 未选中的选中
        data.selected = true
        self:selectCard(id, data)
        self:initiateTargets()
        autoSelectOnlyFeasibleTarget(self, data)
      end
      if self:feasible() then
        self:doOKButton()
      else
        data.selected = false
        self:selectCard(id, data)
        self:initiateTargets()
      end
    end
    ]]
  elseif elemType == "Photo" then
    ---@cast id integer
    self:selectTarget(id, data)
    if #self.selected_targets == 0 then
      autoSelectOnlyFeasibleTarget(self, data)
    end
    -- 双击目标使用卡牌
    --[[
    if action == "doubleClick" and data.doubleClickUse then
      if not data.selected then -- 未选中的选中
        data.selected = true
        self:selectTarget(id, data)
      end
      if self:feasible() then
        self:doOKButton()
      else
        data.selected = false
        self:selectTarget(id, data)
      end
    end
    ]]
  elseif elemType == "Interaction" then
    local ignore = action == "finish"
    self:updateInteraction(data, ignore)
  end

  -- 防止冗余计算
  if elemType ~= "Interaction" then
    self:refreshInteraction()
  end
  self:updatePrompt()
  self:visualizePile()
end

return ReqActiveSkill
