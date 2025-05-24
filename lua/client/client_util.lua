-- SPDX-License-Identifier: GPL-3.0-or-later

-- All functions in this file are used by Qml

function Translate(src)
  return Fk:translate(src)
end

function GetGeneralData(name)
  local general = Fk.generals[name]
  if general == nil then general = Fk.generals["diaochan"] end
  return {
    package = general.package.name,
    extension = general.package.extensionName,
    kingdom = general.kingdom,
    subkingdom = general.subkingdom,
    hp = general.hp,
    maxHp = general.maxHp,
    mainMaxHpAdjustedValue = general.mainMaxHpAdjustedValue,
    deputyMaxHpAdjustedValue = general.deputyMaxHpAdjustedValue,
    shield = general.shield,
    hidden = general.hidden,
    total_hidden = general.total_hidden,
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
    mainMaxHp = general.mainMaxHpAdjustedValue,
    deputyMaxHp = general.deputyMaxHpAdjustedValue,
    gender = general.gender,
    skill = {},
    companions = general.companions
  }
  for _, s in ipairs(general.all_skills) do
    table.insert(ret.skill, {
      name = s[1],
      description = Fk:getDescription(s[1]),
      is_related_skill = s[2],
    })
  end
  for _, g in pairs(Fk.generals) do
    if table.contains(g.companions, general.name) then
      table.insertIfNeed(ret.companions, g.name)
    end
  end
  return ret
end

function GetSameGenerals(name)
  return Fk:getSameGenerals(name)
end

function IsCompanionWith(general, general2)
  local _general, _general2 = Fk.generals[general], Fk.generals[general2]
  return _general:isCompanionWith(_general2)
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

function GetCardData(id, virtualCardForm)
  local card = Fk:getCardById(id)
  if card == nil then return {
    cid = id,
    known = false
  } end
  local mark = {}
  for k, v in pairs(card.mark) do
    if k and k:startsWith("@") and v and v ~= 0 then
      table.insert(mark, {
        k = k, v = v,
      })
    end
  end
  local ret = {
    cid = id,
    name = card.name,
    extension = card.package.extensionName,
    number = card.number,
    suit = card:getSuitString(),
    color = card:getColorString(),
    mark = mark,
    type = card.type,
    subtype = cardSubtypeStrings[card.sub_type],
    -- known = Self:cardVisible(id)
  }
  if card.skillName ~= "" then
    local orig = Fk:getCardById(id, true)
    ret.name = orig.name
    ret.virt_name = card.name
  end
  if virtualCardForm then
    local virtualCard = ClientInstance:getPlayerById(virtualCardForm):getVirualEquip(id)
    if virtualCard then
      ret.virt_name = virtualCard.name
      ret.subtype = cardSubtypeStrings[virtualCard.sub_type]
    end
  end
  return ret
end

function GetCardExtensionByName(cardName)
  local card = Fk.all_card_types[cardName]
  return card and card.package.extensionName or ""
end

function GetAllMods()
  return Fk.extensions
end

function GetAllModNames()
  return Fk.extension_names
end

function GetAllGeneralPack()
  local ret = {}
  for _, name in ipairs(Fk.package_names) do
    if Fk.packages[name].type == Package.GeneralPack then
      table.insert(ret, name)
    end
  end
  return ret
end

function GetAllProperties()
  local kingdoms = {"wei", "shu", "wu", "qun"}
  local maxHps, hps = {}, {}
  for _, g in pairs(Fk.generals) do
    if not g.total_hidden then
      table.insertIfNeed(kingdoms, g.kingdom)
      table.insertIfNeed(maxHps, g.maxHp)
      table.insertIfNeed(hps, g.hp)
    end
  end
  table.sort(maxHps)
  table.sort(hps)
  return { kingdoms = kingdoms, maxHps = maxHps, hps = hps }
end

function GetGenerals(pack_name)
  if not Fk.packages[pack_name] then return {} end
  local ret = {}
  for _, g in ipairs(Fk.packages[pack_name].generals) do
    if not g.total_hidden then
      table.insert(ret, g.name)
    end
  end
  return ret
end

function SearchAllGenerals(word)
  local ret = {}
  for _, name in ipairs(Fk.package_names) do
    if Fk.packages[name].type == Package.GeneralPack then
      table.insertTable(ret, SearchGenerals(name, word))
    end
  end
  return ret
end

function SearchGenerals(pack_name, word)
  local ret = {}
  if word == "" then return GetGenerals(pack_name) end
  for _, g in ipairs(Fk.packages[pack_name].generals) do
    if not g.total_hidden and string.find(Fk:translate(g.name), word) then
      table.insert(ret, g.name)
    end
  end
  return ret
end

---@param a string
---@param t string
---@return boolean
local findSkillAudio = function (a, t)
  local au
  for i = 0, 999 do
    au = i == 0 and a or a .. i
    if Fk:translate(au) ~= au then
      if string.find(Fk:translate(au), t) then return true end
    elseif i > 0 then break end
  end
  return false
end

---@param general General
---@param text string
---@return boolean
local function findAudioText(general, text)
  local audio
  for _, prefix in ipairs{"~", "!"} do
    audio = prefix .. general.name
    if Fk:translate(audio) ~= audio and string.find(Fk:translate(audio), text) then return true end
  end
  for _, s in ipairs(general:getSkillNameList(true)) do
    audio = "$" .. s .. "_" .. general.name
    if findSkillAudio(audio, text) then return true end
    audio = "$" .. s
    if findSkillAudio(audio, text) then return true end
  end
  return false
end

---@param text string
---@return string
local translateInfo = function (text)
  local ret = Fk:translate(text)
  return ret == text and Fk:translate("Official") or ret
end

---@param general General
---@param filter any
---@return boolean
local function filterGeneral(general, filter)
  local genderMapper = {Fk:translate("male"), Fk:translate("female"), Fk:translate("bigender"), Fk:translate("agender")}

  local name = filter.name ---@type string
  local title = filter.title ---@type string
  local kingdoms = filter.kingdoms ---@type string[]
  local maxHps = filter.maxHps ---@type string[]
  local hps = filter.hps ---@type string[]
  local genders = filter.genders ---@type string[]
  local skillName = filter.skillName ---@type string
  local skillDesc = filter.skillDesc ---@type string
  local designer = filter.designer ---@type string
  local voiceActor = filter.voiceActor ---@type string
  local illustrator = filter.illustrator ---@type string
  local audioText = filter.audioText ---@type string
  return not (
    (name ~= "" and not string.find(Fk:translate(general.name), name)) or
    (title ~= "" and not string.find(translateInfo("#" .. general.name), title)) or
    (#kingdoms > 0 and not table.contains(kingdoms, Fk:translate(general.kingdom)) and
      not table.contains(kingdoms, Fk:translate(general.subkingdom))) or
    (#maxHps > 0 and not table.contains(maxHps, tostring(general.maxHp))) or
    (#hps > 0 and not table.contains(hps, tostring(general.hp))) or
    (#genders > 0 and not table.contains(genders, genderMapper[general.gender])) or
    (skillName ~= "" and not table.find(general:getSkillNameList(true), function (s) return
      not not string.find(Fk:translate(s), skillName)
    end)) or
    (skillDesc ~= "" and not table.find(general:getSkillNameList(true), function (s) return
      not not string.find(Fk:getDescription(s), skillDesc)
    end)) or
    (designer ~= "" and not string.find(translateInfo("designer:" .. general.name), designer)) or
    (voiceActor ~= "" and not string.find(translateInfo("cv:" .. general.name), voiceActor)) or
    (illustrator ~= "" and not string.find(translateInfo("illustrator:" .. general.name), illustrator)) or
    (audioText ~= "" and not findAudioText(general, audioText))
  )
end

function FilterAllGenerals(filter)
  local ret = {}
  for _, name in ipairs(Fk.package_names) do
    if Fk.packages[name].type == Package.GeneralPack then
      for _, g in ipairs(Fk.packages[name].generals) do
        if not g.total_hidden and filterGeneral(g, filter) then
          table.insert(ret, g.name)
        end
      end
    end
  end
  return ret
end

function UpdatePackageEnable(pkg, enabled)
  if enabled then
    table.removeOne(ClientInstance.disabled_packs, pkg)
  else
    table.insertIfNeed(ClientInstance.disabled_packs, pkg)
  end
end

function GetAvailableGeneralsNum()
  local generalPool = Fk:getAllGenerals()
  local except = {}
  local ret = 0
  for _, g in ipairs(Fk.packages["test_p_0"].generals) do
    table.insert(except, g.name)
  end

  local availableGenerals = {}
  for _, general in pairs(generalPool) do
    if not table.contains(except, general.name) then
      if (not general.hidden and not general.total_hidden) and
        #table.filter(availableGenerals, function(g)
        return g.trueName == general.trueName
      end) == 0 then
        ret = ret + 1
      end
    end
  end

  return ret
end

function GetAllCardPack()
  local ret = {}
  for _, name in ipairs(Fk.package_names) do
    if Fk.packages[name].type == Package.CardPack then
      table.insert(ret, name)
    end
  end
  return ret
end

function GetCards(pack_name)
  local ret = {}
  for _, c in ipairs(Fk.packages[pack_name].cards) do
    table.insert(ret, c.id)
  end
  return ret
end

function GetCardSkill(cid)
  return Fk:getCardById(cid).skill and Fk:getCardById(cid).skill.name or ""
end

function GetCardSpecialSkills(cid)
  return Fk:getCardById(cid).special_skills or Util.DummyTable
end

function DistanceTo(from, to)
  local a = ClientInstance:getPlayerById(from)
  local b = ClientInstance:getPlayerById(to)
  return a:distanceTo(b)
end

function GetPile(id, name)
  return ClientInstance:getPlayerById(id):getPile(name) or Util.DummyTable
end

function GetAllPiles(id)
  return ClientInstance:getPlayerById(id).special_cards or Util.DummyTable
end

function GetMySkills()
  return table.map(Self.player_skills, function(s)
    return s.visible and s.name or nil
  end)
end

function GetPlayerSkills(id)
  local p = ClientInstance:getPlayerById(id)
  if p == Self then
    return table.map(p.player_skills, function(s)
      local skel = s:getSkeleton() or s
      return s.visible and {
        name = Fk:getSkillName(skel.name, nil, p, true),
        description = Fk:getDescription(s.name, nil, p),
      } or nil
    end)
  else
    return table.map(p.player_skills, function(s)
      local skel = s:getSkeleton() or s
      return s.visible and not (s.attached_equip or s.name:endsWith("&")) and {
        name = Fk:getSkillName(skel.name, nil, p, true),
        description = Fk:getDescription(s.name, nil, p),
      } or nil
    end)
  end
end

-- Handle skills

function GetSkillData(skill_name)
  local skill = Fk.skills[skill_name]
  if not skill then return nil end
  local freq = "notactive"
  if skill:isInstanceOf(ActiveSkill) or skill:isInstanceOf(ViewAsSkill) then
    freq = "active"
  end
  local frequency
  if skill:hasTag(Skill.Limited) then
    frequency = "limit"
  elseif skill:hasTag(Skill.Wake) then
    frequency = "wake"
  elseif skill:hasTag(Skill.Quest) then
    frequency = "quest"
  end
  return {
    skill = Fk:translate(skill_name), --Fk:getSkillName(skill_name, nil, Self, false), -- 需要配套更新技能面板
    orig_skill = skill_name,
    extension = skill.package.extensionName,
    freq = freq,
    frequency = frequency,
    switchSkillName = skill:hasTag(Skill.Switch) and skill:getSkeleton().name or "",
    isViewAsSkill = skill:isInstanceOf(ViewAsSkill),
  }
end

function GetSkillStatus(skill_name)
  local player = Self
  local skill = Fk.skills[skill_name]
  return {
    locked = not skill:isEffectable(player),
    times = skill:getTimes(player)
  }
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
      c = skill:viewAs(Self, selected_cards)
      if c then
        ret = exp:match(c)
      end
    else
      return true
    end
  else
    ret = exp:matchExp(card_name)
  end
  return ret
end

function GetVirtualEquip(player, cid)
  local c = ClientInstance:getPlayerById(player):getVirualEquip(cid)
  if not c then return nil end
  return {
    name = c.name,
    cid = c.subcards[1],
  }
end

function GetGameModes()
  local ret = {}
  for k, v in pairs(Fk.game_modes) do
    table.insert(ret, {
      name = Fk:translate(v.name),
      orig_name = v.name,
      minPlayer = v.minPlayer,
      maxPlayer = v.maxPlayer,
    })
  end
  table.sort(ret, function(a, b) return a.name > b.name end)
  return ret
end

function GetPlayerHandcards(pid)
  local c = ClientInstance
  local p = c:getPlayerById(pid)
  return p and p.player_cards[Player.Hand] or ""
end

function GetPlayerEquips(pid)
  local c = ClientInstance
  local p = c:getPlayerById(pid)
  return p.player_cards[Player.Equip]
end

function ResetClientLua()
  local self = ClientInstance
  local _data = self.enter_room_data;
  local data = self.settings
  Self = ClientPlayer:new(self.client:getSelf())
  self:initialize(self.client) -- clear old client data
  self.players = {Self}
  self.alive_players = {Self}
  self.discard_pile = {}

  self.enter_room_data = _data;
  self.settings = data

  self.disabled_packs = data.disabledPack
  self.disabled_generals = data.disabledGenerals
  -- ClientInstance:notifyUI("EnterRoom", jsonData)
end

function ResetAddPlayer(j)
  fk.client_callback["AddPlayer"](ClientInstance, j)
end

function GetRoomConfig()
  return ClientInstance.settings
end

function GetCompNum()
  local c = ClientInstance
  local mode = Fk.game_modes[c.settings.gameMode]
  local min, max = mode.minComp, mode.maxComp
  local capacity = c.capacity
  if min < 0 then min = capacity + min end
  if max < 0 then max = capacity + max end
  min = math.min(min, max) -- 最小值大于最大值时，取较小的
  local compNum = #table.filter(c.players, function(pl) return pl.id < -1 end)
  return { minComp = min, maxComp = max, curComp = compNum }
end

function GetPlayerGameData(pid)
  local c = ClientInstance
  local p = c:getPlayerById(pid)
  if not p then return {0, 0, 0, 0} end
  local raw = p.player:getGameData()
  local ret = {}
  for _, i in fk.qlist(raw) do
    table.insert(ret, i)
  end
  table.insert(ret, p.player:getTotalGameTime())
  return ret
end

function SetPlayerGameData(pid, data)
  local c = ClientInstance
  local p = c:getPlayerById(pid)
  local total, win, run = table.unpack(data)
  p.player:setGameData(total, win, run)
  table.insert(data, 1, pid)
  ClientInstance:notifyUI("UpdateGameData", data)
end

function FilterMyHandcards()
  Self:filterHandcards()
end

function SetObserving(o)
  ClientInstance.observing = o
end

function SetReplaying(o)
  ClientInstance.replaying = o
end

function SetReplayingShowCards(o)
  ClientInstance.replaying_show = o
  if o then
    for _, p in ipairs(ClientInstance.players) do
      ClientInstance:notifyUI("PropertyUpdate", { p.id, "role_shown", true })
    end
  end
end

function CheckSurrenderAvailable(playedTime)
  local curMode = ClientInstance.settings.gameMode
  return Fk.game_modes[curMode]:surrenderFunc(playedTime)
end

function FindMosts() -- 从所有的玩家结算数据中找出最佳/差玩家
  local data = ClientInstance:getBanner("GameSummary")
  if not data then return end -- 兼容老录像
  local max_damage, max_damaged, max_recover, max_kill = 0, 0, 0, 0
  local least_damage, least_damaged, least_recover, least_kill = 9999, 9999, 9999, 9999
  local maxDamagePlayers, maxDamagedPlayers, maxRecoverPlayers, maxKillPlayers = {}, {}, {}, {}
  local leastDamagePlayers, leastDamagedPlayers, leastRecoverPlayers, leastKillPlayers = {}, {}, {}, {}

  for s, p in ipairs(data) do
    if p.damage >= max_damage and p.damage > 0 then
      if p.damage > max_damage then
        max_damage = p.damage
        maxDamagePlayers = {}
      end
      table.insert(maxDamagePlayers, s)
    end
    if p.damaged >= max_damaged and p.damaged > 0 then
      if p.damaged > max_damaged then
        max_damaged = p.damaged
        maxDamagedPlayers = {}
      end
      table.insert(maxDamagedPlayers, s)
    end
    if p.recover >= max_recover and p.recover > 0 then
      if p.recover > max_recover then
        max_recover = p.recover
        maxRecoverPlayers = {}
      end
      table.insert(maxRecoverPlayers, s)
    end
    if p.kill >= max_kill and p.kill > 0 then
      if p.kill > max_kill then
        max_kill = p.kill
        maxKillPlayers = {}
      end
      table.insert(maxKillPlayers, s)
    end
    if p.damage <= least_damage then
      if p.damage < least_damage then
        least_damage = p.damage
        leastDamagePlayers = {}
      end
      table.insert(leastDamagePlayers, s)
    end

    if p.damaged <= least_damaged then
      if p.damaged < least_damaged then
        least_damaged = p.damaged
        leastDamagedPlayers = {}
      end
      table.insert(leastDamagedPlayers, s)
    end
    if p.recover <= least_recover then
      if p.recover < least_recover then
        least_recover = p.recover
        leastRecoverPlayers = {}
      end
      table.insert(leastRecoverPlayers, s)
    end
    if p.kill <= least_kill then
      if p.kill < least_kill then
        least_kill = p.kill
        leastKillPlayers = {}
      end
      table.insert(leastKillPlayers, s)
    end

  end
  local mosts = {
    maxDamagePlayers = maxDamagePlayers,
    maxDamagedPlayers = maxDamagedPlayers,
    maxRecoverPlayers = maxRecoverPlayers,
    maxKillPlayers = maxKillPlayers,
    leastDamagePlayers = leastDamagePlayers,
    leastDamagedPlayers = leastDamagedPlayers,
    leastRecoverPlayers = leastRecoverPlayers,
    leastKillPlayers = leastKillPlayers,
  }
  ClientInstance:setBanner("GameMosts", mosts)
end

-- 赋予称号，顺带加上武将和角色
function Entitle(data, seat, winner)
  local honor = {}
  seat = seat + 1
  local player = ClientInstance:getPlayerBySeat(seat)
  local result -- 1: 胜, 2: 败, 3: 平局
  if table.contains(winner:split("+"), player.role) then
    result = 1
  elseif winner == "" then
    result = 3
  else
    result = 2
  end

  local mosts = ClientInstance.banners["GameMosts"]
  local mostDamage = table.contains(mosts.maxDamagePlayers, seat)
  local mostDamaged = table.contains(mosts.maxDamagedPlayers, seat)
  local mostRecover = table.contains(mosts.maxRecoverPlayers, seat)
  local mostKill = table.contains(mosts.maxKillPlayers, seat)
  local leastDamage = table.contains(mosts.leastDamagePlayers, seat)
  local leastDamaged = table.contains(mosts.leastDamagedPlayers, seat)
  local leastRecover = table.contains(mosts.leastRecoverPlayers, seat)
  local leastKill = table.contains(mosts.leastKillPlayers, seat)

  local addHonor = function(honorName)
    table.insert(honor, Fk:translate(honorName))
  end
  if data.turn == 0 and player.dead then addHonor("Soy") end -- 打酱油的：没有回合就死
  if data.turn <= 1 and result == 1 then addHonor("Rapid Victory") end -- 旗开得胜：一回合内胜利
  if mostDamage and mostDamaged then addHonor("Burning Soul") end -- 血战：最多伤害，最多受伤
  if mostDamage and data.kill == 0 and result == 2 then addHonor("Regretful Lose") end-- 含恨而终：伤害最多，没有击杀并失败
  if data.kill >= #ClientInstance.players - 2 and data.kill > 0 and result == 2 then addHonor("Close But No Cigar") end -- 功亏一篑：杀死X-2个角色（X为玩家数）但失败
  if leastDamage and mostKill then addHonor("Wicked Kill") end -- 直刺咽喉：最少伤害，最多击杀
  if data.damage == 0 and leastDamaged and data.recover > 0 then addHonor("Peaceful Watcher") end -- 和平主义者：没有伤害，最少受伤，有回血
  if mostKill and mostDamage and mostRecover and data.damage >= 10 and data.recover >= 10 and player:isAlive() and result == 1 then addHonor("MVP") end -- MVP：最多击杀，最多伤害，最多回血，伤害和回血都大于10,存活且获胜
  if data.damage == 0 and data.recover == 0 and data.kill == 0 and data.damaged == 0 then addHonor("Innocent") end -- 无存在感：没有伤害，没有回血，没有击杀，没有受伤
  if mostKill and mostDamage and data.kill > 2 and player.role == "lord" and result == 1 then addHonor("Awe Prestige") end -- 天道威仪：最多击杀，最多伤害，击杀至少3个角色，身份为主公且获胜
  if data.damaged == 0 and player:isAlive() and result == 1 and player.role == "loyalist" then addHonor("Wisely Loyalist") end -- 能臣巧吏：没有受伤，存活，身份为忠臣且获胜
  if data.damaged == 0 and player:isAlive() and result == 1 and player.role == "renegade" then addHonor("Conspiracy") end -- 老谋深算：没有受伤，存活，身份为内奸且获胜
  if mostKill and data.kill > 1 and player.role ~= "lord" and player:isAlive() then addHonor("War Vanguard") end -- 破敌先锋：最多伤害，击杀至少2个角色，身份不为主公且存活
  if data.kill > 1 and player.role == "lord" and result == 2 then addHonor("Lose Prestige") end -- 天道不佑：击杀至少2个角色，身份为主公且失败
  if mostKill and data.kill > 1 and player.role == "lord" and result == 1 then addHonor("Fierce Lord") end -- 一世枭雄：最多击杀，击杀至少2个角色，身份为主公且获胜
  if mostKill and data.kill >= (#ClientInstance.players / 2 + 0.5) then addHonor("Blood Judgement") end -- 嗜血判官：最多击杀，击杀大于一半的角色
  if data.kill >= #ClientInstance.players - 1 and data.kill > 1 then addHonor("Rampage") end -- 横扫千军：杀死X-1个角色（X为玩家数且至少为3）
  if mostKill and mostDamage and result == 2 then addHonor("Failed Ambition") end -- 大业未成：最多击杀，最多伤害但失败
  if data.kill == 1 and player.role == "rebel" and result == 1 and #ClientInstance.players > 2 and #ClientInstance.alive_players + 1 == #ClientInstance.players then addHonor("Direct Regicide") end -- 直捣黄龙：只击杀主公，且只有主公阵亡，身份为反贼
  if mostDamage and result == 1 and player.role ~= "lord" and player:isAlive() then addHonor("Legatus") end -- 破军功臣：最多伤害，存活，身份不为主公且获胜
  if mostDamage and result == 1 and player.role == "lord" then addHonor("Frightful Lord") end -- 势敌千军：最多伤害，身份为主公且获胜
  if mostDamage and data.damage >= 10 and data.damage <= 14 then addHonor("Bloody Warrior") end -- 屠戮之士：最多伤害，伤害10~14点
  if mostDamage and data.damage >= 15 and data.damage <= 19 then addHonor("Warrior Soul") end -- 战魂：最多伤害，伤害15~19点
  if mostDamage and data.damage >= 20 then addHonor("Wrath Warlord") end -- 暴走战神：最多伤害，伤害至少20点
  if mostRecover and data.recover >= 10 then addHonor("Peaceful Healer") end -- 甘霖之润：最多回血，回血至少10点
  if mostRecover and data.recover >= 5 and data.recover <= 9 then addHonor("Brilliant Healer") end -- 妙手回春：最多回血，回血5~9点
  if mostDamaged and data.damage == 0 and player.dead and player.role ~= "lord" then addHonor("Fodder") end -- 炮灰：最多受伤，没有伤害，死亡，身份不为主公
  if mostDamaged and data.damaged >= 15 then addHonor("Fire Target") end -- 集火目标：最多受伤，受伤至少15点
  if mostDamaged and data.damaged >= 10 and player:isAlive() and result == 1 then addHonor("Tank") end -- 肉盾：受伤至少10点，存活且获胜
  if mostDamaged and data.damaged >= 10 and player:isAlive() and result == 2 then addHonor("War Spirit") end -- 军魂：受伤至少10点，存活但失败
  local players = ClientInstance.alive_players
  local loyalistNum, rebelNum, loyalistAll, rebelAll = 0, 0, 0, 0
  for _, p in ipairs(players) do
    if p.role == "loyalist" then
      loyalistAll = loyalistAll + 1
      if p:isAlive() then loyalistNum = loyalistNum + 1 end
    elseif p.role == "rebel" then
      rebelAll = rebelAll + 1
      if p:isAlive() then rebelNum = rebelNum + 1 end
    end
  end
  if player:isAlive() and result == 1 and player.role == "loyalist" and loyalistNum == 1 and loyalistAll > 1 then addHonor("Priority Honor") end -- 竭忠尽智：作为剩余唯一存活的忠臣，获胜
  if player:isAlive() and result == 1 and player.role == "rebel" and rebelNum == 1 and rebelAll > 1 then addHonor("Impasse Strike") end -- 绝境逆袭：作为剩余唯一存活的反贼，获胜
  return {
    honor = table.concat(honor, ", "),
    general = player.general,
    deputy = player.deputyGeneral,
    role = player.role,
  }
end

function SaveRecord()
  local c = ClientInstance
  c.client:saveRecord(json.encode(c.record), c.record[2])
end

function GetCardProhibitReason(cid)
  local card = Fk:getCardById(cid)
  if not card then return "" end
  local handler = ClientInstance.current_request_handler
  if (not handler) or (not handler:isInstanceOf(Fk.request_handlers["AskForUseActiveSkill"])) then return "" end
  local method, pattern = "", handler.pattern or "."

  if handler.class.name == "ReqPlayCard" then method = "play"
  elseif handler.class.name == "ReqResponseCard" then method = "response"
  elseif handler.class.name == "ReqUseCard" then method = "use"
  elseif handler.skill_name == "discard_skill" then method = "discard"
  end

  if method == "play" and not card.skill:canUse(Self, card) then return "" end
  if method ~= "play" and not card:matchPattern(pattern) then return "" end
  if method == "play" then method = "use" end

  local fn_table = {
    use = "prohibitUse",
    response = "prohibitResponse",
    discard = "prohibitDiscard",
  }
  local str_table = {
    use = "method_use",
    response = "method_response_play",
    discard = "method_discard",
  }
  if not fn_table[method] then return "" end

  local status_skills = Fk:currentRoom().status_skills[ProhibitSkill] or Util.DummyTable
  local s
  for _, skill in ipairs(status_skills) do
    local fn = skill[fn_table[method]]
    if fn(skill, Self, card) then
      s = skill
      break
    end
  end
  if not s then return "" end

  -- try to return a translated string
  local skillName = s.name
  local ret = Fk:translate(skillName)
  if ret ~= skillName then
    return ret .. Fk:translate("prohibit") .. Fk:translate(str_table[method])
  elseif skillName:endsWith("_prohibit") and skillName:startsWith("#") then
    return Fk:translate(skillName:sub(2, -10)) .. Fk:translate("prohibit") .. Fk:translate(str_table[method])
  else
    return ret
  end
end

function GetTargetTip(pid)
  local handler = ClientInstance.current_request_handler --[[@as ReqPlayCard ]]
  if (not handler) or (not handler:isInstanceOf(Fk.request_handlers["AskForUseActiveSkill"])) then return "" end

  local to_select = pid
  local selected = handler.selected_targets
  local selected_cards = handler.pendings
  local card = handler.selected_card --[[@as Card?]]
  local skill = Fk.skills[handler.skill_name]
  local photo = handler.scene.items["Photo"][pid] --[[@as Photo]]
  if not photo then return {} end
  local selectable = photo.enabled
  local extra_data = handler.extra_data

  local ret = {}

  if skill then
    if skill:isInstanceOf(ActiveSkill) then
      ---@cast skill ActiveSkill
      local tip = skill:targetTip(Self, ClientInstance:getPlayerById(to_select),
        table.map(selected, Util.Id2PlayerMapper), selected_cards, nil, selectable, extra_data)
      if type(tip) == "string" then
        table.insert(ret, { content = tip, type = "normal" })
      elseif type(tip) == "table" then
        table.insertTable(ret, tip)
      end
    elseif skill:isInstanceOf(ViewAsSkill) then
      ---@cast skill ViewAsSkill
      card = skill:viewAs(Self, selected_cards)
    end
  end

  if card then
    local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable
    for _, sk in ipairs(status_skills) do
      ret = ret or {}
      if #ret > 4 then
        return ret
      end

      local tip = sk:getTargetTip(Self, ClientInstance:getPlayerById(to_select),
        table.map(selected, Util.Id2PlayerMapper), selected_cards, card, selectable, extra_data)
      if type(tip) == "string" then
        table.insert(ret, { content = tip, type = "normal" })
      elseif type(tip) == "table" then
        table.insertTable(ret, tip)
      end
    end

    ret = ret or {}
    local tip = card.skill:targetTip(Self, ClientInstance:getPlayerById(to_select),
      table.map(selected, Util.Id2PlayerMapper), selected_cards, card, selectable, extra_data)
    if type(tip) == "string" then
      table.insert(ret, { content = tip, type = "normal" })
    elseif type(tip) == "table" then
      table.insertTable(ret, tip)
    end
  end

  return ret
end

function CanSortHandcards(pid)
  return ClientInstance:getPlayerById(pid):getMark(MarkEnum.SortProhibited) == 0
end

function PoxiPrompt(poxi_type, data, extra_data)
  local poxi = Fk.poxi_methods[poxi_type]
  if not poxi or not poxi.prompt then return "" end
  if type(poxi.prompt) == "string" then return Fk:translate(poxi.prompt) end
  return Fk:translate(poxi.prompt(data, extra_data))
end

function PoxiFilter(poxi_type, to_select, selected, data, extra_data)
  local poxi = Fk.poxi_methods[poxi_type]
  if not poxi then return false end
  return poxi.card_filter(to_select, selected, data, extra_data)
end

function PoxiFeasible(poxi_type, selected, data, extra_data)
  local poxi = Fk.poxi_methods[poxi_type]
  if not poxi then return false end
  return poxi.feasible(selected, data, extra_data)
end

function GetQmlMark(mtype, name, value, p)
  local spec = Fk.qml_marks[mtype]
  if not spec then return {} end
  p = ClientInstance:getPlayerById(p)
  value = json.decode(value)
  return {
    qml_path = type(spec.qml_path) == "function" and spec.qml_path(name, value, p) or spec.qml_path,
    text = spec.how_to_show(name, value, p)
  }
end

function GetMiniGame(gtype, p, data)
  local spec = Fk.mini_games[gtype]
  p = ClientInstance:getPlayerById(p)
  data = json.decode(data)
  return {
    qml_path = type(spec.qml_path) == "function" and spec.qml_path(p, data) or spec.qml_path,
  }
end

function ReloadPackage(path)
  Fk:reloadPackage(path)
end

function GetPendingSkill()
  local h = ClientInstance.current_request_handler
  local reqActive = Fk.request_handlers["AskForUseActiveSkill"]
  return h and h:isInstanceOf(reqActive) and
    (h.selected_card == nil and h.skill_name) or ""
end

function RevertSelection()
  local h = ClientInstance.current_request_handler ---@type ReqActiveSkill
  local reqActive = Fk.request_handlers["AskForUseActiveSkill"]
  if not (h and h:isInstanceOf(reqActive) and h.pendings) then return end
  h.change = {}
  -- 1. 取消选中所有已选 2. 尝试选中所有之前未选的牌
  local unselectData = { selected = false }
  local selectData = { selected = true }
  local to_select = {}
  local lastcid
  local lastselected = false
  for cid, cardItem in pairs(h.scene:getAllItems("CardItem")) do
    if table.contains(h.pendings, cid) then
      lastcid = cid
      h:selectCard(cid, unselectData)
    else
      table.insert(to_select, cardItem)
    end
  end
  for _, cardItem in ipairs(to_select) do
    if cardItem.enabled then
      lastcid = cardItem.id
      lastselected = true
      h:selectCard(cardItem.id, selectData)
    end
  end
  -- 最后模拟一次真实点击卡牌以更新目标和按钮状态
  if lastcid then
    h:selectCard(lastcid, { selected = not lastselected })
    h:update("CardItem", lastcid, "click", { selected = lastselected })
  end
  h.scene:notifyUI()
end

local requestUIUpdating = false
function UpdateRequestUI(elemType, id, action, data)
  if requestUIUpdating then return end
  requestUIUpdating = true
  local h = ClientInstance.current_request_handler
  if not h then
    requestUIUpdating = false
    return
  end
  h.change = {}
  local finish = h:update(elemType, id, action, data)
  if not finish then
    h.scene:notifyUI()
  else
    h:_finish()
  end
  requestUIUpdating = false
end

function FinishRequestUI()
  local h = ClientInstance.current_request_handler
  if h then
    h:_finish()
    ClientInstance.current_request_handler = nil
  end
end

function CardVisibility(cardId)
  local player = Self
  local card = Fk:getCardById(cardId)
  if not card then return false end
  return player:cardVisible(cardId)
end

function RoleVisibility(targetId)
  local player = Self
  local target = ClientInstance:getPlayerById(targetId)
  if not target then return false end
  return player:roleVisible(target)
end

function IsMyBuddy(me, other)
  local from = ClientInstance:getPlayerById(me)
  local to = ClientInstance:getPlayerById(other)
  return from and to and from:isBuddy(to)
end

-- special_name 为nil时是手牌
function HasVisibleCard(me, other, special_name)
  local from = ClientInstance:getPlayerById(me)
  local to = ClientInstance:getPlayerById(other)
  if not (from and to) then return false end
  local ids
  if not special_name then ids = to:getCardIds("h")
  else ids = to:getPile(special_name) end

  for _, id in ipairs(ids) do
    if from:cardVisible(id) then
      return true
    end
  end
  return false
end

function RefreshStatusSkills()
  local self = ClientInstance
  -- if not self.recording then return end -- 在回放录像就别刷了
  -- 刷所有人手牌上限，体力值及可见标记；以及身份可见性
  for _, p in ipairs(self.alive_players) do
    self:notifyUI("MaxCard", {
      pcardMax = p:getMaxCards(),
      php = p.hp,
      id = p.id,
    })

    for k, v in pairs(p.mark) do
      if k and k:startsWith("@") and v and v ~= 0 then
        if k:startsWith("@[") and k:find(']') then
          local close = k:find(']')
          local mtype = k:sub(3, close - 1)
          local spec = Fk.qml_marks[mtype]
          if spec then
            local text = spec.how_to_show(k, v, p)
            if text == "#hidden" then v = 0 end
          end
        end
        self:notifyUI("SetPlayerMark", { p.id, k, v })
      end
    end

    self:notifyUI("PropertyUpdate", {
      p.id, "role_shown", not not RoleVisibility(p.id)
    })
  end
  -- 刷自己的手牌
  for _, cid in ipairs(Self:getCardIds("h")) do
    self:notifyUI("UpdateCard", cid)
  end
  Self:filterHandcards()
  -- 刷技能状态
  self:notifyUI("UpdateSkill", nil)
end

function GetPlayersAndObservers()
  local self = ClientInstance
  local players = table.connect(self.observers, self.players)
  local ret = {}
  for _, p in ipairs(players) do
    table.insert(ret, {
      id = table.contains(self.players, p) and p.id or p.player:getId(),
      general = p.general,
      deputy = p.deputyGeneral,
      name = p.player:getScreenName(),
      observing = table.contains(self.observers, p),
      avatar = p.player:getAvatar(),
    })
  end
  return ret
end

dofile "lua/client/i18n/init.lua"
