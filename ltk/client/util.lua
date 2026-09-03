local M = {}

function M:getGeneralData(name)
  local general = Fk.generals[name]
  if general == nil then general = Fk.generals["diaochan"] end
  return {
    package = general.package.name,
    extension = general.package.extensionName,
    prefix = general.prefix,
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

function M:getGeneralDetail(name)
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
    companions = {},
    headnote = general.headnote,
    endnote = general.endnote,
  }
  local skill_names = general:getSkillNameList(true, false)
  for _, s in ipairs(general.all_skills) do
    local s_name = s[1]
    table.insert(ret.skill, {
      name = s_name,
      description = Fk:getDescription(s_name),
      is_related_skill = s[2],
    })
    for _ = 1, 2 do -- 最多两层相关技能
      for _, rs in ipairs(Fk.skill_skels[s_name].related_skills) do
        s_name = rs
        if not table.contains(skill_names, s_name) then -- 如果不存在，插入
          table.insert(ret.skill, {
            name = s_name,
            description = Fk:getDescription(s_name),
            is_related_skill = true,
          })
        end
      end
    end
  end
  local _companions = {}
  for _, gname in ipairs(general.companions) do
    local name_splited = gname:split("__")
    if table.insertIfNeed(_companions, name_splited[#name_splited]) then
      table.insert(ret.companions, gname) -- 只显示一个（防止trueName没有翻译）
    end
  end
  for _, g in pairs(Fk.generals) do
    if table.contains(g.companions, general.name) and table.insertIfNeed(_companions, g.trueName) then -- 按照name判断
      table.insertIfNeed(ret.companions, g.name) -- 只显示一个（防止trueName没有翻译）
    end
  end
  return ret
end

function M:getSameGenerals(name)
  return Fk:getSameGenerals(name)
end

function M:canMatchInHegemony(general, deputy, enabled_kingdoms)
  return Fk:canMatchInHegemony(general, deputy, enabled_kingdoms)
end

function M:isCompanionWith(general, general2)
  local _general, _general2 = Fk.generals[general], Fk.generals[general2]
  return _general:isCompanionWith(_general2)
end

M.cardSubtypeStrings = {
  [Card.SubtypeNone] = "none",
  [Card.SubtypeDelayedTrick] = "delayed_trick",
  [Card.SubtypeWeapon] = "weapon",
  [Card.SubtypeArmor] = "armor",
  [Card.SubtypeDefensiveRide] = "defensive_ride",
  [Card.SubtypeOffensiveRide] = "offensive_ride",
  [Card.SubtypeTreasure] = "treasure",
}

---@param id integer
---@param filterCard? boolean @ 是否获取经过锁视的牌？
function M:getCardData(id, filterCard)
  local card = Fk:getCardById(id, not filterCard)
  if card == nil then
    return {
      cid = id,
      known = false
    }
  end
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
    subtype = M.cardSubtypeStrings[card.sub_type],
    pic_name = card:getPicName(),
  }
  if filterCard and card.skillName ~= "" then
    local orig = Fk:getCardById(id, true)
    ret.name = orig.name
    ret.virt_name = card.name
  end
  if card.sub_type == Card.SubtypeWeapon then ---@cast card Weapon
    local owner = ClientInstance:getCardOwner(card) or Self
    ret.attack_range = card:getAttackRange(owner)
  end
  return ret
end

function M:getCardExtensionByName(cardName)
  local card = Fk.all_card_types[cardName]
  return card and card.package.extensionName or ""
end

function M:getAllGeneralPack()
  local ret = {}
  for _, name in ipairs(Fk.package_names) do
    if Fk.packages[name].type == Package.GeneralPack then
      table.insert(ret, name)
    end
  end
  return ret
end

function M:getAllProperties()
  local kingdoms = { "wei", "shu", "wu", "qun" }
  local maxHps, hps = {}, {}
  for _, g in pairs(Fk.generals) do
    if not g.total_hidden then
      table.insertIfNeed(kingdoms, g.kingdom)
      table.insertIfNeed(maxHps, g.maxHp)
      table.insertIfNeed(hps, g.hp)
    end
  end
  local enabledStates = { Fk:translate("Enable"), Fk:translate("Disabled") }
  table.sort(maxHps)
  table.sort(hps)
  return { kingdoms = kingdoms, maxHps = maxHps, hps = hps, enabledStates = enabledStates }
end

function M:getGenerals(pack_name)
  if not Fk.packages[pack_name] then return {} end
  local ret = {}
  for _, g in ipairs(Fk.packages[pack_name].generals) do
    if not g.total_hidden then
      table.insert(ret, g.name)
    end
  end
  return ret
end

function M:searchAllGenerals(word)
  local ret = {}
  for _, name in ipairs(Fk.package_names) do
    if Fk.packages[name].type == Package.GeneralPack then
      table.insertTable(ret, self:searchGenerals(name, word))
    end
  end
  return ret
end

function M:searchGenerals(pack_name, word)
  local ret = {}
  if word == "" then return self:getGenerals(pack_name) end
  for _, g in ipairs(Fk.packages[pack_name].generals) do
    if not g.total_hidden and string.find(g.name, word) or string.find(Fk:translate(g.name), word) then
      table.insert(ret, g.name)
    end
  end
  return ret
end

---@param a string
---@param t string
---@return boolean
local findSkillAudio = function(a, t)
  local au
  for i = 0, 999 do
    au = i == 0 and a or a .. i
    if Fk:translate(au) ~= au then
      if string.find(Fk:translate(au), t) then return true end
    elseif i > 0 then
      break
    end
  end
  return false
end

---@param general General
---@param text string
---@return boolean
local function findAudioText(general, text)
  local audio
  for _, prefix in ipairs { "~", "!" } do
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
local translateInfo = function(text)
  local ret = Fk:translate(text)
  return ret == text and Fk:translate("Official") or ret
end

---封装 string.find 并默认自动转义特殊字符（按字面匹配）
---@param str string|number 目标字符串（待查找的文本）
---@param pattern string|number 查找模式（可能包含特殊字符）
---@param start_pos? integer 起始查找位置，默认为 1（字符串第一个字符位置）
---@param plain? boolean
---@param auto_escape? boolean
---@return integer|nil start
---@return integer|nil end
---@return any|nil ... captured
local function find_with_escape(str, pattern, start_pos, plain, auto_escape)
  -- 处理可选参数的默认值
  start_pos = start_pos or 1         -- 默认为从第一个字符开始查找
  plain = plain or false             -- 默认为模式匹配（非纯文本）
  auto_escape = auto_escape ~= false -- 默认为自动转义（除非显式传 false）

  -- 仅在需要模式匹配（plain=false）且开启自动转义时，处理特殊字符
  if auto_escape and not plain then
    local special_chars = "([%.%+%-%*%?%[%^%$%(%)%%])"    -- 需转义的特殊字符列表
    pattern = string.gsub(pattern, special_chars, "%%%1") -- 转义处理
  end

  -- 调用原生 string.find，保持功能一致
  return string.find(str, pattern, start_pos, plain)
end



---@param general General
---@param filter any
---@return boolean
local function filterGeneral(general, filter)
  local genderMapper = { Fk:translate("male"), Fk:translate("female"), Fk:translate("bigender"), Fk:translate("agender") }

  local name = filter.name ---@type string
  local title = filter.title ---@type string
  local headnote = filter.headnote ---@type string
  local endnote = filter.endnote ---@type string
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
  local enabledStates = filter.enabledStates ---@type string[]
  local skinStates = filter.skinStates ---@type string[]
  return not (
    (name ~= "" and not find_with_escape(Fk:translate(general.name), name)) or
    (title ~= "" and not find_with_escape(translateInfo("#" .. general.name), title)) or
    (headnote ~= "" and not find_with_escape(Fk:translate(general.headnote), headnote)) or
    (endnote ~= "" and not find_with_escape(Fk:translate(general.endnote), endnote)) or
    (#kingdoms > 0 and not table.contains(kingdoms, Fk:translate(general.kingdom)) and
      not table.contains(kingdoms, Fk:translate(general.subkingdom))) or
    (#maxHps > 0 and not table.contains(maxHps, tostring(general.maxHp))) or
    (#hps > 0 and not table.contains(hps, tostring(general.hp))) or
    (#genders > 0 and not table.contains(genders, genderMapper[general.gender])) or
    (skillName ~= "" and not table.find(general:getSkillNameList(true, true), function(s)
      return not not (find_with_escape(s, skillName) or find_with_escape(Fk:translate(s), skillName))
    end)) or
    (skillDesc ~= "" and not table.find(general:getSkillNameList(true, true), function(s)
      return not not find_with_escape(Fk:getDescription(s), skillDesc)
    end)) or
    (designer ~= "" and not find_with_escape(translateInfo("designer:" .. general.name), designer)) or
    (voiceActor ~= "" and not find_with_escape(translateInfo("cv:" .. general.name), voiceActor)) or
    (illustrator ~= "" and not find_with_escape(translateInfo("illustrator:" .. general.name), illustrator)) or
    (audioText ~= "" and not findAudioText(general, audioText)) or
    (#enabledStates > 0 and not table.contains(enabledStates, Fk:canUseGeneral(general.name) and Fk:translate("Enable") or Fk:translate("Disabled"))) or
    (#skinStates > 0 and not table.contains(skinStates, #Fk:getSkinNamesByGeneral(general.name) > 0 and Fk:translate("Available") or Fk:translate("Unavailable")))
  )
end

function M:filterAllGenerals(filter)
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

function M:updatePackageEnable(pkg, enabled)
  if enabled then
    table.removeOne(ClientInstance.disabled_packs, pkg)
  else
    table.insertIfNeed(ClientInstance.disabled_packs, pkg)
  end
end

function M:getAvailableGeneralsNum()
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

function M:getAllCardPack()
  local ret = {}
  for _, name in ipairs(Fk.package_names) do
    if Fk.packages[name].type == Package.CardPack then
      table.insert(ret, name)
    end
  end
  return ret
end

function M:getCards(pack_name)
  local ret = {}
  for _, c in ipairs(Fk.packages[pack_name].cards) do
    table.insert(ret, c.id)
  end
  return ret
end

function M:getPlayerSkills(id)
  local p = ClientInstance:getPlayerById(id)
  local isSelf = p == Self
  return table.map(p.player_skills, function(s)
    local skel = s:getSkeleton()
    local include = s.visible and (isSelf or not (s.attached_equip or s.name:endsWith("&"))) -- 其他角色的装备技能和按钮技能不显示
    return include and {
      name = Fk:getSkillName(skel.name, nil, p, true),
      description = Fk:getDescription(s.name, nil, p),
      orig_name = skel.name,
      related_skills = Fk.skill_skels[skel.name].related_skills or {},
    } or nil
  end)
end


--- 获取卡牌描述
---@param cardId integer
---@return string
function M:getCardDescription(cardId)
  local card = Fk:getCardById(cardId)
  if not card then return "" end
  -- 注意player参数是观察者，不是卡牌拥有者
  return card:getDynamicDescription(Self) or ""
end

--- 获取卡牌牌名
---@param cardId integer
---@param filterCard? boolean @ 是否应用锁视效果，默认否
---@return string
function M:getCardName(cardId, filterCard)
  local card = Fk:getCardById(cardId, not filterCard)
  if not card then return "" end
  -- 应用虚拟装备
  if filterCard then
    local owner = ClientInstance:getCardOwner(cardId)
    if owner then
      local vcard = owner:getVirtualEquip(cardId)
      card = vcard or card
    end
  end
  -- 注意player参数是观察者，不是卡牌拥有者
  return card:getDynamicName(Self) or ""
end

--- 获取牌在UI上显示的名字（+1-1马默认+1-1）
---@param cardId integer
---@param filterCard? boolean @ 是否应用锁视效果，默认否
---@return string
function M:getCardUIName(cardId, filterCard)
  local card = Fk:getCardById(cardId, not filterCard)
  if not card then return "" end
  -- 应用虚拟装备
  if filterCard then
    local owner = ClientInstance:getCardOwner(cardId)
    if owner then
      local vcard = owner:getVirtualEquip(cardId)
      card = vcard or card
    end
  end
  if card.ui_name then return Fk:translate(card.ui_name) end
  if card.sub_type == Card.SubtypeDefensiveRide then
    return "+1"
  elseif card.sub_type == Card.SubtypeOffensiveRide then
    return "-1"
  end
  return card:getDynamicName(Self) or ""
end

function M:getEnableKingdoms(general)
  return Fk:getKingdomsNeedToChoose(general)
end

function M:getKingdomInHegemony(general, deputy, enabled_kingdoms)
  return Fk:getKingdomInHegemony(general, deputy, enabled_kingdoms)
end

-- Handle skills

function M:getSkillData(skill_name)
  local skill = Fk.skills[skill_name]
  if not skill then return nil end
  local freq = "notactive"
  if skill:isInstanceOf(ActiveSkill) or skill:isInstanceOf(ViewAsSkill) then
    freq = "active"
  end
  local frequency
  if skill:hasTag(Skill.Compulsory, false) then
    frequency = "compulsory"
  elseif skill:hasTag(Skill.Limited, false) then
    frequency = "limit"
  elseif skill:hasTag(Skill.Wake) then
    frequency = "wake"
  elseif skill:hasTag(Skill.Quest) then
    frequency = "quest"
  end
  return {
    skill = Fk:getSkillName(skill_name, nil, Self),
    orig_skill = skill_name,
    extension = skill.package.extensionName,
    freq = freq,
    frequency = frequency,
    switchSkillName = (skill:hasTag(Skill.Switch) or skill:hasTag(Skill.Rhyme)) and skill:getSkeleton().name or "",
  }
end

-- card_name may be id, name of card, or json string
function M:cardFitPattern(card_name, pattern)
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

--- 获取某牌的虚拟装备/延时锦囊信息
---@param playerid integer @ 拥有此牌的角色id，找不到时会在全场找此牌拥有者
---@param cid integer @ 牌的id
function M:getVirtualEquipData(playerid, cid)
  local c, player
  player = ClientInstance:getPlayerById(playerid)
  if not player then
    for _, p in ipairs(ClientInstance.players) do
      c = p:getVirtualEquip(cid)
      if c then break end
    end
  end
  if player then
    c = player:getVirtualEquip(cid)
  end
  if not c then return nil end
  return {
    name = c.name,
    cid = c.subcards[1],
    extension = c.package.extensionName,
    suit = c:getSuitString(),
    number = c.number,
    type = c.type,
    subtype = c:getSubtypeString(),
  }
end

function M:getSkinNamesByGeneral(general)
  return Fk:getSkinNamesByGeneral(general)
end

function M:getSkinByName(general, name)
  local skin_data =  Fk:getSkinByName(general, name)
  if (skin_data or {}).name then
    local _skin = table.simpleClone(skin_data)
    _skin.url = skin_data.path .. skin_data.name
    return _skin
  end
  return
end

function M:findMosts()          -- 从所有的玩家结算数据中找出最佳/差玩家
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
function M:entitle(data, seat, winner)
  local honor = {}
  seat = seat + 1
  local player = ClientInstance:getPlayerBySeat(seat)
  local result -- 1: 胜, 2: 败, 3: 平局
  if table.contains(winner:split("+"), tostring(player.id)) then
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

  -- 打酱油的：没有回合就死
  if data.turn == 0 and player.dead then
    addHonor("Soy")
  end
  -- 旗开得胜：一回合内胜利
  if data.turn <= 1 and result == 1 and ClientInstance:getBanner("RoundCount") == 1 then
    addHonor("Rapid Victory")
  end
  -- 血战：最多伤害，最多受伤
  if mostDamage and mostDamaged then
    addHonor("Burning Soul")
  end
  -- 含恨而终：伤害最多，没有击杀并失败
  if mostDamage and data.kill == 0 and result == 2 then
    addHonor("Regretful Lose")
  end
  -- 功亏一篑：杀死X-2个角色（X为玩家数）但失败
  if data.kill >= #ClientInstance.players - 2 and data.kill > 0 and result == 2 then
    addHonor("Close But No Cigar")
  end
  -- 直刺咽喉：最少伤害，最多击杀
  if leastDamage and mostKill then
    addHonor("Wicked Kill")
  end
  -- 和平主义者：没有伤害，最少受伤，有回血
  if data.damage == 0 and leastDamaged and data.recover > 0 then
    addHonor("Peaceful Watcher")
  end
  -- MVP：最多击杀，最多伤害，最多回血，伤害和回血都大于10,存活且获胜
  if mostKill and mostDamage and mostRecover and data.damage >= 10 and data.recover >= 10 and player:isAlive() and result == 1 then
    addHonor("MVP")
  end
  -- 无存在感：没有伤害，没有回血，没有击杀，没有受伤
  if data.damage == 0 and data.recover == 0 and data.kill == 0 and data.damaged == 0 then
    addHonor("Innocent")
  end
  -- 天道威仪：最多击杀，最多伤害，击杀至少3个角色，身份为主公且获胜
  if mostKill and mostDamage and data.kill > 2 and player.role == "lord" and result == 1 then
    addHonor("Awe Prestige")
  end
  -- 能臣巧吏：没有受伤，存活，身份为忠臣且获胜
  if data.damaged == 0 and player:isAlive() and result == 1 and player.role == "loyalist" then
    addHonor("Wisely Loyalist")
  end
  -- 老谋深算：没有受伤，存活，身份为内奸且获胜
  if data.damaged == 0 and player:isAlive() and result == 1 and player.role == "renegade" then
    addHonor("Conspiracy")
  end
  -- 破敌先锋：最多伤害，击杀至少2个角色，身份不为主公且存活
  if mostKill and data.kill > 1 and player.role ~= "lord" and player:isAlive() then
    addHonor("War Vanguard")
  end
  -- 天道不佑：击杀至少2个角色，身份为主公且失败
  if data.kill > 1 and player.role == "lord" and result == 2 then
    addHonor("Lose Prestige")
  end
  -- 一世枭雄：最多击杀，击杀至少2个角色，身份为主公且获胜
  if mostKill and data.kill > 1 and player.role == "lord" and result == 1 then
    addHonor("Fierce Lord")
  end
  -- 嗜血判官：最多击杀，击杀大于一半的角色
  if mostKill and data.kill >= (#ClientInstance.players / 2 + 0.5) then
    addHonor("Blood Judgement")
  end
  -- 横扫千军：杀死X-1个角色（X为玩家数且至少为3）
  if data.kill >= #ClientInstance.players - 1 and data.kill > 1 then
    addHonor("Rampage")
  end
  -- 大业未成：最多击杀，最多伤害但失败
  if mostKill and mostDamage and result == 2 then
    addHonor("Failed Ambition")
  end
  -- 直捣黄龙：只击杀主公，且只有主公阵亡，身份为反贼
  if data.kill == 1 and player.role == "rebel" and result == 1 and #ClientInstance.players > 2 and #ClientInstance.alive_players + 1 == #ClientInstance.players then
    addHonor("Direct Regicide")
  end
  -- 破军功臣：最多伤害，存活，身份不为主公且获胜
  if mostDamage and result == 1 and player.role ~= "lord" and player:isAlive() then
    addHonor("Legatus")
  end
  -- 势敌千军：最多伤害，身份为主公且获胜
  if mostDamage and result == 1 and player.role == "lord" then
    addHonor("Frightful Lord")
  end
  -- 屠戮之士：最多伤害，伤害10~14点
  if mostDamage and data.damage >= 10 and data.damage <= 14 then
    addHonor("Bloody Warrior")
  end
  -- 战魂：最多伤害，伤害15~19点
  if mostDamage and data.damage >= 15 and data.damage <= 19 then
    addHonor("Warrior Soul")
  end
  -- 暴走战神：最多伤害，伤害至少20点
  if mostDamage and data.damage >= 20 then
    addHonor("Wrath Warlord")
  end
  -- 甘霖之润：最多回血，回血至少10点
  if mostRecover and data.recover >= 10 then
    addHonor("Peaceful Healer")
  end
  -- 妙手回春：最多回血，回血5~9点
  if mostRecover and data.recover >= 5 and data.recover <= 9 then
    addHonor("Brilliant Healer")
  end
  -- 炮灰：最多受伤，没有伤害，死亡，身份不为主公
  if mostDamaged and data.damage == 0 and player.dead and player.role ~= "lord" then
    addHonor("Fodder")
  end
  -- 集火目标：最多受伤，受伤至少15点
  if mostDamaged and data.damaged >= 15 then
    addHonor("Fire Target")
  end
  -- 肉盾：受伤至少10点，存活且获胜
  if mostDamaged and data.damaged >= 10 and player:isAlive() and result == 1 then
    addHonor("Tank")
  end
  -- 军魂：受伤至少10点，存活但失败
  if mostDamaged and data.damaged >= 10 and player:isAlive() and result == 2 then
    addHonor("War Spirit")
  end

  local players = ClientInstance.alive_players
  local loyalistNum, rebelNum, loyalistAll, rebelAll = 0, 0, 0, 0
  for _, p in ipairs(players) do
    if p.role == "loyalist" then
      loyalistAll = loyalistAll + 1
      if p:isAlive() then
        loyalistNum = loyalistNum + 1
      end
    elseif p.role == "rebel" then
      rebelAll = rebelAll + 1
      if p:isAlive() then
        rebelNum = rebelNum + 1
      end
    end
  end
  -- 竭忠尽智：作为剩余唯一存活的忠臣，获胜
  if player:isAlive() and result == 1 and player.role == "loyalist" and loyalistNum == 1 and loyalistAll > 1 then
    addHonor("Priority Honor")
  end
  -- 绝境逆袭：作为剩余唯一存活的反贼，获胜
  if player:isAlive() and result == 1 and player.role == "rebel" and rebelNum == 1 and rebelAll > 1 then
    addHonor("Impasse Strike")
  end

  return {
    honor = table.concat(honor, ", "),
    general = player.general,
    deputy = player.deputyGeneral,
    role = player.role,
  }
end

function M:getCardProhibitReason(cid)
  local card = Fk:getCardById(cid)
  if not card then return "" end
  local handler = ClientInstance.current_request_handler
  if (not handler) or (not handler:isInstanceOf(ClientInstance.request_handlers["AskForUseActiveSkill"])) then return "" end
  ---@cast handler ReqUseCard
  local method, pattern = "", handler.pattern or "."

  if handler.class.name == "ReqPlayCard" then
    method = "play"
  elseif handler.class.name == "ReqResponseCard" then
    method = "response"
  elseif handler.class.name == "ReqUseCard" then
    method = "use"
  elseif handler.skill_name == "discard_skill" then
    method = "discard"
  end

  if method == "play" and not card:getSkill(Self):canUse(Self, card) then return "" end
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

function M:getCardTip(cid)
  local handler = ClientInstance.current_request_handler --[[@as ReqPlayCard ]]
  if (not handler) or (not handler:isInstanceOf(ClientInstance.request_handlers["AskForUseActiveSkill"])) then return "" end

  local to_select = cid
  local selected = handler.pendings
  local selected_targets = handler.selected_targets
  local card = handler.selected_card --[[@as Card?]]
  local skill = Fk.skills[handler.skill_name]
  local CardItem = handler.scene.items["CardItem"][cid] --[[@as CardItem]]
  if not CardItem then return {} end
  local selectable = CardItem.enabled
  local extra_data = handler.extra_data

  local ret = {}

  if skill then
    if skill:isInstanceOf(ActiveSkill) then
      ---@cast skill ActiveSkill
      local tip = skill:cardTip(Self, to_select, selected, table.map(selected_targets, Util.Id2PlayerMapper), nil, selectable, extra_data)
      if type(tip) == "string" then
        table.insert(ret, { content = tip, type = "normal" })
      elseif type(tip) == "table" then
        table.insertTable(ret, tip)
      end
    elseif skill:isInstanceOf(ViewAsSkill) then
      ---@cast skill ViewAsSkill
      local tip = skill:cardTip(Self, to_select, selected, table.map(selected_targets, Util.Id2PlayerMapper), nil, selectable, extra_data)
      if type(tip) == "string" then
        table.insert(ret, { content = tip, type = "normal" })
      elseif type(tip) == "table" then
        table.insertTable(ret, tip)
      end
      card = skill:viewAs(Self, selected)
    end
  end

  if card then
    local status_skills = Fk:currentRoom().status_skills[TargetModSkill] or Util.DummyTable ---@type TargetModSkill[]
    for _, sk in ipairs(status_skills) do
      ret = ret or {}
      if #ret > 4 then
        return ret
      end

      local tip = sk:getCardTip(Self, to_select, selected, table.map(selected_targets, Util.Id2PlayerMapper), card, selectable, extra_data)
      if type(tip) == "string" then
        table.insert(ret, { content = tip, type = "normal" })
      elseif type(tip) == "table" then
        table.insertTable(ret, tip)
      end
    end

    ret = ret or {}
    local tip = card:getSkill(Self):cardTip(Self, to_select, selected, table.map(selected_targets, Util.Id2PlayerMapper), card, selectable, extra_data)
    if type(tip) == "string" then
      table.insert(ret, { content = tip, type = "normal" })
    elseif type(tip) == "table" then
      table.insertTable(ret, tip)
    end
  end
  return ret
end

function M:getTargetTip(pid)
  local handler = ClientInstance.current_request_handler --[[@as ReqPlayCard ]]
  if (not handler) or (not handler:isInstanceOf(ClientInstance.request_handlers["AskForUseActiveSkill"])) then return "" end

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
    local tip = card:getSkill(Self):targetTip(Self, ClientInstance:getPlayerById(to_select),
      table.map(selected, Util.Id2PlayerMapper), selected_cards, card, selectable, extra_data)
    if type(tip) == "string" then
      table.insert(ret, { content = tip, type = "normal" })
    elseif type(tip) == "table" then
      table.insertTable(ret, tip)
    end
  end

  return ret
end

function M:canSortHandcards(pid)
  local cplayer = ClientInstance:getPlayerById(pid)
  if cplayer then
    -- for m, _ in pairs(cplayer.mark) do
    --   if m == MarkEnum.SortProhibited or m:startsWith(MarkEnum.SortProhibited .. "-") then return false end
    -- end
    return cplayer:canSortHandcards()
  end
  return true
end

function M:chooseGeneralPrompt(rule_name, data, extra_data)
  local rule = Fk.choose_general_rule[rule_name]
  if not rule or not rule.prompt then return "" end
  if type(rule.prompt) == "string" then return Fk:translate(rule.prompt) end
  return Fk:translate(rule.prompt(data, extra_data))
end

function M:chooseGeneralFilter(rule_name, to_select, selected, data, extra_data)
  local rule = Fk.choose_general_rule[rule_name]
  if not rule then return false end
  return rule.card_filter(to_select, selected, data, extra_data)
end

function M:chooseGeneralFeasible(rule_name, selected, data, extra_data)
  local rule = Fk.choose_general_rule[rule_name]
  if not rule then return false end
  return rule.feasible(selected, data, extra_data)
end

function M:poxiPrompt(poxi_type, data, extra_data, selected)
  local poxi = Fk.poxi_methods[poxi_type]
  if not poxi then return end
  local prompt = poxi.prompt
  if not prompt then return "" end
  if type(prompt) == "string" then
    return prompt
  else
    return prompt(data, extra_data, selected)
  end
end

function M:poxiFilter(poxi_type, to_select, selected, data, extra_data)
  local poxi = Fk.poxi_methods[poxi_type]
  if not poxi then return false end
  return poxi.card_filter(to_select, selected, data, extra_data)
end

function M:poxiFeasible(poxi_type, selected, data, extra_data)
  local poxi = Fk.poxi_methods[poxi_type]
  if not poxi then return false end
  return poxi.feasible(selected, data, extra_data)
end

function M:getMiniGame(gtype, p, data)
  local spec = Fk.mini_games[gtype]
  p = ClientInstance:getPlayerById(p)
  data = json.decode(data)
  return {
    qml_path = type(spec.qml_path) == "function" and spec.qml_path(p, data) or spec.qml_path,
    model = type(spec.model) == "function" and spec.model(p, data) or spec.model,
  }
end

function M:revertSelection()
  local h = ClientInstance.current_request_handler --[[@as ReqActiveSkill]]
  local reqActive = ClientInstance.request_handlers["AskForUseActiveSkill"]
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

-- special_name 为nil时是手牌
function M:hasVisibleCard(me, other, special_name)
  local from = ClientInstance:getPlayerById(me)
  local to = ClientInstance:getPlayerById(other)
  if not (from and to) then return false end
  local ids
  if not special_name then
    ids = to:getCardIds("h")
  else
    ids = to:getPile(special_name)
  end

  for _, id in ipairs(ids) do
    if from:cardVisible(id) then
      return true
    end
  end
  return false
end

--- 刷新状态技状态和UI等
function M:refreshStatusSkills()
  -- 刷所有人手牌上限，体力值及可见标记；以及身份可见性
  for _, p in ipairs(ClientInstance.alive_players) do
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
        ClientInstance:notifyUI("SetPlayerMark", { p.id, k, v })
      end
    end
  end
end

return M
