-- All functions in this file are used by Qml

function Translate(src)
  return Fk:translate(src)
end

function GetGeneralData(name)
  local general = Fk.generals[name]
  if general == nil then general = Fk.generals["diaochan"] end
  return json.encode {
    package = general.package.name,
    extension = general.package.extensionName,
    kingdom = general.kingdom,
    hp = general.hp,
    maxHp = general.maxHp
  }
end

function GetGeneralDetail(name)
  local general = Fk.generals[name]
  if general == nil then general = Fk.generals["diaochan"] end
  local ret = {
    package = general.package.name,
    extension = general.package.extensionName,
    kingdom = general.kingdom,
    hp = general.hp,
    maxHp = general.maxHp,
    skill = {}
  }
  for _, s in ipairs(general.skills) do
    table.insert(ret.skill, {
      name = s.name,
      description = Fk:getDescription(s.name)
    })
  end
  for _, s in ipairs(general.other_skills) do
    table.insert(ret.skill, {
      name = s,
      description = Fk:getDescription(s)
    })
  end
  return json.encode(ret)
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
  local card = Fk:getCardById(id)
  if card == nil then return json.encode{
    cid = id,
    known = false
  } end
  local ret = {
    cid = id,
    name = card.name,
    extension = card.package.extensionName,
    number = card.number,
    suit = card:getSuitString(),
    color = card.color,
    subtype = cardSubtypeStrings[card.sub_type]
  }
  if card.skillName ~= "" then
    local orig = Fk:getCardById(id, true)
    ret.name = orig.name
    ret.virt_name = card.name
  end
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

function DistanceTo(from, to)
  local a = ClientInstance:getPlayerById(from)
  local b = ClientInstance:getPlayerById(to)
  return a:distanceTo(b)
end

---@param card string | integer
---@param player integer
function CanUseCard(card, player)
  local c   ---@type Card
  if type(card) == "number" then
    c = Fk:getCardById(card)
  else
    local data = json.decode(card)
    local skill = Fk.skills[data.skill]
    local selected_cards = data.subcards
    if skill:isInstanceOf(ViewAsSkill) then
      c = skill:viewAs(selected_cards)
      if not c then
        return "false"
      end
    else
      -- ActiveSkill should return true here
      return "true"
    end
  end

  local ret = c.skill:canUse(ClientInstance:getPlayerById(player), c)
  return json.encode(ret)
end

---@param card string | integer
---@param to_select integer @ id of the target
---@param selected integer[] @ ids of selected targets
---@param selected_cards integer[] @ ids of selected cards
function CanUseCardToTarget(card, to_select, selected)
  if ClientInstance:getPlayerById(to_select).dead then
    return "false"
  end
  local c   ---@type Card
  local selected_cards
  if type(card) == "number" then
    c = Fk:getCardById(card)
    selected_cards = {card}
  else
    local t = json.decode(card)
    return ActiveTargetFilter(t.skill, to_select, selected, t.subcards)
  end

  local ret = c.skill:targetFilter(to_select, selected, selected_cards, c)
  if ret then
    local r = Fk:currentRoom()
    local status_skills = r.status_skills[ProhibitSkill] or {}
    for _, skill in ipairs(status_skills) do
      if skill:isProhibited(Self, r:getPlayerById(to_select), c) then
        ret = false
        break
      end
    end
  end
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
  if skill:isInstanceOf(ActiveSkill) or skill:isInstanceOf(ViewAsSkill) then
    freq = "active"
  end
  return json.encode{
    skill = Fk:translate(skill_name),
    orig_skill = skill_name,
    extension = skill.package.extensionName,
    freq = freq
  }
end

function ActiveCanUse(skill_name)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill then
    if skill:isInstanceOf(ActiveSkill) then
      ret = skill:canUse(Self)
    elseif skill:isInstanceOf(ViewAsSkill) then
      ret = skill:enabledAtPlay(Self)
      if ret then
        local exp = Exppattern:Parse(skill.pattern)
        local cnames = {}
        for _, m in ipairs(exp.matchers) do
          if m.name then table.insertTable(cnames, m.name) end
        end
        for _, n in ipairs(cnames) do
          local c = Fk:cloneCard(n)
          ret = c.skill:canUse(Self, c)
          if ret then break end
        end
      end
    end
  end
  return json.encode(ret)
end

function ActiveCardFilter(skill_name, to_select, selected, selected_targets)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill then
    if skill:isInstanceOf(ActiveSkill) then
      ret = skill:cardFilter(to_select, selected, selected_targets)
    elseif skill:isInstanceOf(ViewAsSkill) then
      ret = skill:cardFilter(to_select, selected)
    end
  end
  return json.encode(ret)
end

function ActiveTargetFilter(skill_name, to_select, selected, selected_cards)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill then
    if skill:isInstanceOf(ActiveSkill) then
      ret = skill:targetFilter(to_select, selected, selected_cards)
    elseif skill:isInstanceOf(ViewAsSkill) then
      local card = skill:viewAs(selected_cards)
      if card then
        ret = card.skill:targetFilter(to_select, selected, selected_cards)
      end
    end
  end
  return json.encode(ret)
end

function ActiveFeasible(skill_name, selected, selected_cards)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill then
    if skill:isInstanceOf(ActiveSkill) then
      ret = skill:feasible(selected, selected_cards)
    elseif skill:isInstanceOf(ViewAsSkill) then
      local card = skill:viewAs(selected_cards)
      if card then
        ret = card.skill:feasible(selected, selected_cards)
      end
    end
  end
  return json.encode(ret)
end

function CanViewAs(skill_name, card_ids)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill then
    if skill:isInstanceOf(ViewAsSkill) then
      ret = skill:viewAs(card_ids) ~= nil
    elseif skill:isInstanceOf(ActiveSkill) then
      ret = true
    end
  end
  return json.encode(ret)
end

-- card_name may be id, name of card, or json string
function CardFitPattern(card_name, pattern)
  local exp = Exppattern:Parse(pattern)
  local c
  local ret = false
  if type(card_name) == "number" then
    c = Fk:getCardById(card_name)
    ret = exp:match(c)
  elseif string.sub(card_name, 1, 1) == "{" then
    local data = json.decode(card_name)
    local skill = Fk.skills[data.skill]
    local selected_cards = data.subcards
    if skill:isInstanceOf(ViewAsSkill) then
      c = skill:viewAs(selected_cards)
      if c then
        ret = exp:match(c)
      end
    else
      return "true"
    end
  else
    ret = exp:matchExp(card_name)
  end
  return json.encode(ret)
end

function SkillFitPattern(skill_name, pattern)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill and skill.pattern then
    local exp = Exppattern:Parse(pattern)
    ret = exp:matchExp(skill.pattern)
  end
  return json.encode(ret)
end

function SkillCanResponse(skill_name)
  local skill = Fk.skills[skill_name]
  local ret = false
  if skill and skill:isInstanceOf(ViewAsSkill) then
    ret = skill:enabledAtResponse(Self)
  end
  return json.encode(ret)
end

function GetVirtualEquip(player, cid)
  local c = ClientInstance:getPlayerById(player):getVirualEquip(cid)
  if not c then return "null" end
  return json.encode{
    name = c.name,
    cid = c.subcards[1],
  }
end

Fk:loadTranslationTable{
  -- Lobby
  ["Room List"] = "房间列表",
  ["Enter"] = "进入",
  ["Observe"] = "旁观",

  ["Edit Profile"] = "编辑个人信息",
  ["Username"] = "用户名",
  ["Avatar"] = "头像",
  ["Old Password"] = "旧密码",
  ["New Password"] = "新密码",
  ["Update Avatar"] = "更新头像",
  ["Update Password"] = "更新密码",
  ["Lobby BG"] = "大厅壁纸",
  ["Room BG"] = "房间背景",
  ["Game BGM"] = "游戏BGM",

  ["Create Room"] = "创建房间",
  ["Room Name"] = "房间名字",
  ["$RoomName"] = "%1的房间",
  ["Player num"] = "玩家数目",
  ["Enable free assign"] = "自由选将",

  ["Generals Overview"] = "武将一览",
  ["Cards Overview"] = "卡牌一览",
  ["Scenarios Overview"] = "玩法一览",
  ["Replay"] = "录像",
  ["About"] = "关于",
  ["about_freekill_description"] = "<b>关于FreeKill</b><br/>" ..
    "以便于DIY为首要目的的开源三国杀游戏。<br/>" ..
    "<br/>项目链接： https://github.com/Notify-ctrl/FreeKill",
  ["about_qt_description"] = "<b>关于Qt</b><br/>" ..
    "Qt是一个C++图形界面应用程序开发框架，拥有强大的跨平台能力以及易于使用的API。<br/>" ..
    "<br/>本程序使用Qt 6.2+，主要利用QtQuick开发UI，同时也使用Qt的网络库开发服务端程序。<br/>" ..
    "<br/>官网： https://www.qt.io",
  ["about_lua_description"] = "<b>关于Lua</b><br/>" ..
    "Lua是一种小巧、灵活、高效的脚本语言，广泛用于游戏开发中。<br/>" ..
    "<br/>本程序使用Lua 5.4，利用其完全实现了整个游戏逻辑。<br/>" ..
    "<br/>官网： https://www.lua.org",
  ["about_ossl_description"] = "<b>关于OpenSSL</b><br/>" ..
    "OpenSSL是一个开源包，用来提供安全通信与各种加密支持。<br/>" ..
    "<br/>本程序目前用到了crypto库，以获得RSA加密算法支持。<br/>" ..
    "<br/>官网： https://www.openssl.org",
  ["about_gplv3_description"] = "<b>关于GPLv3</b><br/>" ..
    "GNU通用公共许可协议（简称GPL）是一个广泛使用的自由软件许可证条款，它确保广大用户自由地使用、学习、共享或修改软件。<br/>" ..
    "<br/>由于Qt是按照GPLv3协议开源的库，与此同时本程序用到的readline库也属于GPLv3库，再加上QSanguosha也是以GPLv3协议开源的软件（从中借鉴了不少代码和思路），因此这个项目也使用GPLv3协议开源。<br/>" ..
    "<br/>官网： https://gplv3.fsf.org",
  ["about_sqlite_description"] = "<b>关于SQLite</b><br/>" ..
    "SQLite是一个轻量级的数据库，具有占用资源低、运行效率快、嵌入性好等优点。<br/>" ..
    "<br/>FreeKill使用sqlite3在服务端保存用户的各种信息。<br/>" ..
    "<br/>官网： https://www.sqlite.org",
  ["about_git2_description"] = "<b>关于Libgit2</b><br/>" ..
    "Libgit2是一个轻量级的、跨平台的、纯C实现的库，支持Git的大部分核心操作，并且支持几乎任何能与C语言交互的编程语言。<br/>" ..
    "<br/>FreeKill使用的是libgit2的C API，与此同时使用Git完成拓展包的下载、更新、管理等等功能。<br/>" ..
    "<br/>官网： https://libgit2.org",

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
  ["#choose-trigger"] = "请选择一项技能发动",
  ["trigger"] = "选择技能",
  ["Please arrange cards"] = "请拖拽移动卡牌",

  [" thinking..."] = " 思考中...",
  ["AskForGeneral"] = "选择武将",
  ["AskForGuanxiong"] = "观星",
  ["AskForChoice"] = "选择",
  ["PlayCard"] = "出牌",

  ["AskForCardChosen"] = "选牌",
  ["#AskForChooseCard"] = "%1：请选择其一张卡牌",
  ["$ChooseCard"] = "请选择一张卡牌",
  ["$Hand"] = "手牌区",
  ["$Equip"] = "装备区",
  ["$Judge"] = "判定区",
  ["#AskForUseActiveSkill"] = "请使用技能 %1",
  ["#AskForUseCard"] = "请使用卡牌 %1",
  ["#AskForResponseCard"] = "请打出卡牌 %1",
  ["#AskForNullification"] = "是否为目标为 %dest 的 %arg 使用无懈可击？",
  ["#AskForNullificationWithoutTo"] = "是否对 %src 使用的 %arg 使用无懈可击？",

  ["#AskForDiscard"] = "请弃置 %arg 张牌，最少 %arg2 张",

  ["Trust"] = "托管",
  ["Sort Cards"] = "牌序",
  ["Chat"] = "聊天",
  ["Log"] = "战报",
  ["Trusting ..."] = "托管中 ...",
  ["Observing ..."] = "旁观中 ...",

  ["$GameOver"] = "游戏结束",
  ["$Winner"] = "%1 获胜",
  ["Back To Lobby"] = "返回大厅",
}

-- Game concepts
Fk:loadTranslationTable{
  ["lord"] = "主公",
  ["loyalist"] = "忠臣",
  ["rebel"] = "反贼",
  ["renegade"] = "内奸",
  ["lord+loyalist"] = "主忠",

  ["normal_damage"] = "无属性",
  ["fire_damage"] = "火属性",
  ["thunder_damage"] = "雷属性",

  ["phase_judge"] = "判定阶段",
  ["phase_draw"] = "摸牌阶段",
  ["phase_play"] = "出牌阶段",
  ["phase_discard"] = "弃牌阶段",
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
  
  ["$DrawCards"] = "%from 摸了 %arg 张牌 %card",
  ["$DiscardCards"] = "%from 弃置了 %arg 张牌 %card",

  -- phase
  ["#PhaseSkipped"] = "%from 跳过了 %arg",

  -- useCard
  ["#UseCard"] = "%from 使用了牌 %card",
  ["#UseCardToTargets"] = "%from 使用了牌 %card，目标是 %to",
  ["#CardUseCollaborator"] = "%from 在此次 %arg 中的子目标是 %to",
  ["#UseCardToCard"] = "%from 使用了牌 %card，目标是 %arg",
  ["#ResponsePlayCard"] = "%from 打出了牌 %card",

  ["#UseVCard"] = "%from 将 %card 当 %arg 使用",
  ["#UseVCardToTargets"] = "%from 将 %card 当 %arg 使用，目标是 %to",
  ["#UseVCardToCard"] = "%from 将 %card 当 %arg2 使用，目标是 %arg",
  ["#ResponsePlayVCard"] = "%from 将 %card 当 %arg 打出",
  ["#UseV0Card"] = "%from 使用了 %arg",
  ["#UseV0CardToTargets"] = "%from 使用了 %arg，目标是 %to",
  ["#UseV0CardToCard"] = "%from 使用了 %arg2，目标是 %arg",
  ["#ResponsePlayV0Card"] = "%from 打出了 %arg",

  ["#FilterCard"] = "由于 %arg 的效果，与 %from 相关的 %arg2 被视为了 %arg3",

  -- skill
  ["#InvokeSkill"] = "%from 发动了 “%arg”",

  -- judge
  ["#StartJudgeReason"] = "%from 开始了 %arg 的判定",
  ["#InitialJudge"] = "%from 的判定牌为 %card",
  ["#ChangedJudge"] = "%from 发动“%arg”把 %to 的判定牌改为 %card",
  ["#JudgeResult"] = "%from 的判定结果为 %card",

  -- turnOver
  ["#TurnOver"] = "%from 将武将牌翻面，现在是 %arg",
	["face_up"] = "正面朝上",
	["face_down"] = "背面朝上",

  -- damage, heal and lose HP
  ["#Damage"] = "%to 对 %from 造成了 %arg 点 %arg2 伤害",
  ["#DamageWithNoFrom"] = "%from 受到了 %arg 点 %arg2 伤害",
  ["#LoseHP"] = "%from 失去了 %arg 点体力",
  ["#HealHP"] = "%from 回复了 %arg 点体力",
  ["#ShowHPAndMaxHP"] = "%from 现在的体力值为 %arg，体力上限为 %arg2",

  -- dying and death
  ["#EnterDying"] = "%from 进入了濒死阶段",
  ["#KillPlayer"] = "%from [%arg] 阵亡，凶手是 %to",
  ["#KillPlayerWithNoKiller"] = "%from [%arg] 阵亡，无伤害来源",

  -- misc
  ["#GuanxingResult"] = "%from 的观星结果为 %arg 上 %arg2 下",
}
