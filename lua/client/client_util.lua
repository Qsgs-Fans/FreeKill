-- All functions in this file are used by Qml

function Translate(src)
  return Fk:translate(src)
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

  local ret = c.skill:canUse(ClientInstance:getPlayerById(player))
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
    local t = json.decode(card)
    return ActiveTargetFilter(t.skill, to_select, selected, t.subcards)
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
    local t = json.decode(card)
    return ActiveFeasible(t.skill, selected_targets, t.subcards)
  end

  local ret = c.skill:feasible(selected_targets, selected_cards)
  return json.encode(ret)
end

-- Handle skills

function GetSkillData(skill_name)
  local skill = Fk.skills[skill_name]
  local freq = "notactive"
  if skill:isInstanceOf(ActiveSkill) then
    freq = "active"
  end
  return json.encode{
    skill = Fk:translate(skill_name),
    orig_skill = skill_name,
    freq = freq
  }
end

function ActiveCanUse(skill_name)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill and skill:isInstanceOf(ActiveSkill) then
    ret = skill:canUse(Self)
  end
  return json.encode(ret)
end

function ActiveCardFilter(skill_name, to_select, selected, selected_targets)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill and skill:isInstanceOf(ActiveSkill) then
    ret = skill:cardFilter(to_select, selected, selected_targets)
  end
  return json.encode(ret)
end

function ActiveTargetFilter(skill_name, to_select, selected, selected_cards)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill and skill:isInstanceOf(ActiveSkill) then
    ret = skill:targetFilter(to_select, selected, selected_cards)
  end
  return json.encode(ret)
end

function ActiveFeasible(skill_name, selected, selected_cards)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill and skill:isInstanceOf(ActiveSkill) then
    ret = skill:feasible(selected, selected_cards)
  end
  return json.encode(ret)
end

-- ViewAsSkill (Todo)
function CanViewAs(skill_name, card_ids)
  return "true"
end

Fk:loadTranslationTable{
  -- Lobby
  ["Room List"] = "房间列表",
  ["Enter"] = "进入",

  ["Edit Profile"] = "编辑个人信息",
  ["Username"] = "用户名",
  ["Avatar"] = "头像",
  ["Old Password"] = "旧密码",
  ["New Password"] = "新密码",
  ["Update Avatar"] = "更新头像",
  ["Update Password"] = "更新密码",

  ["Create Room"] = "创建房间",
  ["Room Name"] = "房间名字",
  ["$RoomName"] = "%1的房间",
  ["Player num"] = "玩家数目",

  ["Generals Overview"] = "武将一览",
  ["Cards Overview"] = "卡牌一览",
  ["Scenarios Overview"] = "玩法一览",
  ["About"] = "关于",
  ["Exit Lobby"] = "退出大厅",

  ["OK"] = "确定",
  ["Cancel"] = "取消",
  ["End"] = "结束",
  ["Quit"] = "退出",

  ["$WelcomeToLobby"] = "欢迎进入FreeKill游戏大厅！",

  -- Room
  ["$EnterRoom"] = "成功加入房间。",
  ["$Choice"] = "%1：请选择",
  ["$ChooseGeneral"] = "请选择 %1 名武将",
  ["Fight"] = "出战",

  ["#PlayCard"] = "出牌阶段，请使用一张牌",
  ["#AskForGeneral"] = "请选择 1 名武将",
  ["#AskForSkillInvoke"] = "你想发动技能“%1”吗？",
  ["#AskForChoice"] = "%1：请选择",

  [" thinking..."] = " 思考中...",
  ["AskForGeneral"] = "选择武将",
  ["AskForChoice"] = "选择",
  ["PlayCard"] = "出牌",

  ["AskForCardChosen"] = "选牌",
  ["#AskForChooseCard"] = "%1：请选择其一张卡牌",
  ["$ChooseCard"] = "请选择一张卡牌",
  ["$Hand"] = "手牌区",
  ["$Equip"] = "装备区",
  ["$Judge"] = "判定区",
  ["#AskForUseActiveSkill"] = "请使用技能 %1",
}

-- related to sendLog
Fk:loadTranslationTable{
  -- game processing
  ["$AppendSeparator"] = '<font color="grey">------------------------------</font>',
  ["$GameStart"] = "== 游戏开始 ==",
  ["$GameEnd"] = "== 游戏结束 ==",

  -- get/lose skill
  ["#AcquireSkill"] = "%from 获得了技能“%arg”",
	["#LoseSkill"] = "%from 失去了技能“%arg”",

  -- moveCards (they are sent by notifyMoveCards)
  ["unknown_card"] = '<font color="#B5BA00"><b>未知牌</b></font>',
  ["log_spade"] = "♠",
  ["log_heart"] = '<font color="#CC3131">♥</font>',
  ["log_club"] = "♣",
  ["log_diamond"] = '<font color="#CC3131">♦</font>',
  ["log_nosuit"] = "无花色",
  ["nosuit"] = "无花色",
  ["spade"] = "黑桃",
  ["heart"] = "红桃",
  ["club"] = "梅花",
  ["diamond"] = "方块",
  
  ["$DrawCards"] = "%from 摸了 %arg 张牌 %card",
  ["$DiscardCards"] = "%from 弃置了 %arg 张牌 %card",

  -- useCard
  ["#UseCard"] = "%from 使用了牌 %card",
  ["#UseCardToTargets"] = "%from 使用了牌 %card，目标是 %to",

  -- judge
  ["#InitialJudge"] = "%from 的判定牌为 %card",
  ["#ChangedJudge"] = "%from 发动“%arg”把 %to 的判定牌改为 %card",
  ["#JudgeResult"] = "%from 的判定结果为 %card",

  -- turnOver
  ["#TurnOver"] = "%from 将武将牌翻面，现在是 %arg",
	["face_up"] = "正面朝上",
	["face_down"] = "背面朝上",
}
