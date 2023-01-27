local extension = Package:new("standard")
extension.metadata = require "packages.standard.metadata"
dofile "packages/standard/game_rule.lua"
dofile "packages/standard/aux_skills.lua"

Fk:loadTranslationTable{
  ["standard"] = "标准包",
  ["wei"] = "魏",
  ["shu"] = "蜀",
  ["wu"] = "吴",
  ["qun"] = "群",
}

Fk:loadTranslationTable{
  ["black"] = "黑色",
  ["red"] = '<font color="#CC3131">红色</font>',
  ["nocolor"] = '<font color="grey">无色</font>',
}

local jianxiong = fk.CreateTriggerSkill{
  name = "jianxiong",
  anim_type = "masochism",
  events = {fk.Damaged},
  can_trigger = function(self, event, target, player, data)
    local room = target.room
    return data.card ~= nil and
      target == player and
      target:hasSkill(self.name) and
      room:getCardArea(data.card) == Card.Processing and
      not target.dead
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:obtainCard(player.id, data.card, false)
  end,
}
local caocao = General:new(extension, "caocao", "wei", 4)
caocao:addSkill(jianxiong)
Fk:loadTranslationTable{
  ["caocao"] = "曹操",
  ["jianxiong"] = "奸雄",
}

local guicai = fk.CreateTriggerSkill{
  name = "guicai",
  anim_type = "control",
  events = {fk.AskForRetrial},
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self.name) and not player:isKongcheng()
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local prompt = "#guicai-ask::" .. target.id
    local card = room:askForResponse(player, self.name, ".|.|.|hand", prompt, true)
    if card ~= nil then
      self.cost_data = card
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:retrial(self.cost_data, player, data, self.name)
  end,
}
local fankui = fk.CreateTriggerSkill{
  name = "fankui",
  anim_type = "masochism",
  events = {fk.Damaged},
  frequency = Skill.NotFrequent,
  can_trigger = function(self, event, target, player, data)
    local room = target.room
    local from = room:getPlayerById(data.from)
    return from ~= nil and
      target == player and
      target:hasSkill(self.name) and
      (not from:isNude()) and
      not target.dead
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = room:getPlayerById(data.from)
    local card = room:askForCardChosen(player, from, "he", self.name)
    room:obtainCard(player.id, card, false)
  end
}
local simayi = General:new(extension, "simayi", "wei", 3)
simayi:addSkill(guicai)
simayi:addSkill(fankui)
Fk:loadTranslationTable{
  ["simayi"] = "司马懿",
  ["guicai"] = "鬼才",
  ["#guicai-ask"] = "是否发动“鬼才”，打出一张手牌修改 %dest 的判定？",
  ["fankui"] = "反馈",
}

local ganglie = fk.CreateTriggerSkill{
  name = "ganglie",
  anim_type = "masochism",
  events = {fk.Damaged},
  can_trigger = function(self, event, target, player, data)
    local room = target.room
    return data.from ~= nil and
      target == player and
      target:hasSkill(self.name) and
      not target.dead
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = room:getPlayerById(data.from)
    local judge = {
      who = from,
      reason = self.name,
      pattern = ".|.|spade,club,diamond",
    }
    room:judge(judge)
    if judge.card.suit ~= Card.Heart then
      local discards = room:askForDiscard(from, 2, 2, false, self.name)
      if #discards == 0 then
        room:damage{
          from = player.id,
          to = from.id,
          damage = 1,
          skillName = self.name,
        }
      end
    end
  end,
}
local xiahoudun = General:new(extension, "xiahoudun", "wei", 4)
xiahoudun:addSkill(ganglie)
Fk:loadTranslationTable{
  ["xiahoudun"] = "夏侯惇",
  ["ganglie"] = "刚烈",
}

local tuxi = fk.CreateTriggerSkill{
  name = "tuxi",
  anim_type = "control",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    local ret = (target == player and player:hasSkill(self.name) and player.phase == Player.Draw)
    if ret then
      local room = player.room
      for _, p in ipairs(room:getOtherPlayers(player)) do
        if not p:isKongcheng() then
          return true
        end
      end
    end
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local other = room:getOtherPlayers(player)
    local targets = {}
    for _, p in ipairs(other) do
      if not p:isKongcheng() then
        table.insert(targets, p.id)
      end
    end

    local result = room:askForChoosePlayers(player, targets, 1, 2, "#tuxi-ask", self.name)
    if #result > 0 then
      self.cost_data = result
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, id in ipairs(self.cost_data) do
      local p = room:getPlayerById(id)
      local c = room:askForCardChosen(player, p, "h", self.name)
      room:obtainCard(player.id, c, false)
    end
    return true
  end,
}
local zhangliao = General:new(extension, "zhangliao", "wei", 4)
zhangliao:addSkill(tuxi)
Fk:loadTranslationTable{
  ["zhangliao"] = "张辽",
  ["tuxi"] = "突袭",
  ["#tuxi-ask"] = "是否发动“突袭”，改为获得1-2名角色各一张牌？",
}

local luoyi = fk.CreateTriggerSkill{
  name = "luoyi",
  anim_type = "offensive",
  events = {fk.DrawNCards},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and data.n > 0
  end,
  on_use = function(self, event, target, player, data)
    data.n = data.n - 1
  end,

  refresh_events = {fk.DamageCaused},
  can_refresh = function(self, event, target, player, data)
    if not (target == player and player:hasSkill(self.name) and
      player:usedSkillTimes(self.name) > 0) then
      return
    end

    local c = data.card
    return c and c.name == "slash" or c.name == "duel"
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:broadcastSkillInvoke(self.name)
    room:notifySkillInvoked(player, self.name)
    data.damage = data.damage + 1
  end,
}
local xuchu = General:new(extension, "xuchu", "wei", 4)
xuchu:addSkill(luoyi)
Fk:loadTranslationTable{
  ["xuchu"] = "许褚",
  ["luoyi"] = "裸衣",
}

local tiandu = fk.CreateTriggerSkill{
  name = "tiandu",
  events = {fk.FinishJudge},
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:obtainCard(player.id, data.card)
  end,
}
local guojia = General:new(extension, "guojia", "wei", 3)
guojia:addSkill(tiandu)
Fk:loadTranslationTable{
  ["guojia"] = "郭嘉",
  ["tiandu"] = "天妒",
}

local luoshen = fk.CreateTriggerSkill{
  name = "luoshen",
  anim_type = "drawcard",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      player.phase == Player.Start
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    while true do
      local judge = {
        who = player,
        reason = self.name,
        pattern = ".|A~K|spade,club",
      }
      room:judge(judge)
      if judge.card.color ~= Card.Black then
        break
      end

      if not room:askForSkillInvoke(player, self.name) then
        break
      end
    end
  end,

  refresh_events = {fk.FinishJudge},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      data.reason == self.name and data.card.color == Card.Black
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:obtainCard(player.id, data.card)
  end,
}
local qingguo = fk.CreateViewAsSkill{
  name = "qingguo",
  anim_type = "defensive",
  pattern = "jink",
  card_filter = function(self, to_select, selected)
    if #selected == 1 then return false end
    return Fk:getCardById(to_select).color == Card.Black
      and ClientInstance:getCardArea(to_select) ~= Player.Equip
  end,
  view_as = function(self, cards)
    if #cards ~= 1 then
      return nil
    end
    local c = Fk:cloneCard("jink")
    c:addSubcard(cards[1])
    return c
  end,
}
local zhenji = General:new(extension, "zhenji", "wei", 3, 3, General.Female)
zhenji:addSkill(luoshen)
zhenji:addSkill(qingguo)
Fk:loadTranslationTable{
  ["zhenji"] = "甄姬",
  ["luoshen"] = "洛神",
  ["qingguo"] = "倾国",
}

local liubei = General:new(extension, "liubei", "shu", 4)
Fk:loadTranslationTable{
  ["liubei"] = "刘备",
}

local wusheng = fk.CreateViewAsSkill{
  name = "wusheng",
  anim_type = "offensive",
  pattern = "slash",
  card_filter = function(self, to_select, selected)
    if #selected == 1 then return false end
    return Fk:getCardById(to_select).color == Card.Red
  end,
  view_as = function(self, cards)
    if #cards ~= 1 then
      return nil
    end
    local c = Fk:cloneCard("slash")
    c:addSubcard(cards[1])
    return c
  end,
}
local guanyu = General:new(extension, "guanyu", "shu", 4)
guanyu:addSkill(wusheng)
Fk:loadTranslationTable{
  ["guanyu"] = "关羽",
  ["wusheng"] = "武圣",
}

local zhangfei = General:new(extension, "zhangfei", "shu", 4)
Fk:loadTranslationTable{
  ["zhangfei"] = "张飞",
}

local guanxing = fk.CreateTriggerSkill{
  name = "guanxing",
  anim_type = "control",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      player.phase == Player.Start
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:askForGuanxing(player, room:getNCards(math.min(5, #room.alive_players)))
  end,
}
local kongcheng = fk.CreateProhibitSkill{
  name = "kongcheng",
  is_prohibited = function(self, from, to, card)
    if to:hasSkill(self.name) and to:isKongcheng() then
      return card.name == "slash" or card.name == "duel"
    end
  end,
}
local zhugeliang = General:new(extension, "zhugeliang", "shu", 3)
zhugeliang:addSkill(guanxing)
zhugeliang:addSkill(kongcheng)
Fk:loadTranslationTable{
  ["zhugeliang"] = "诸葛亮",
  ["guanxing"] = "观星",
  ["kongcheng"] = "空城",
}

local longdan = fk.CreateViewAsSkill{
  name = "longdan",
  pattern = "slash,jink",
  card_filter = function(self, to_select, selected)
    if #selected == 1 then return false end
    local c = Fk:getCardById(to_select)
    return c.name == "slash" or c.name == "jink"
  end,
  view_as = function(self, cards)
    if #cards ~= 1 then
      return nil
    end
    local _c = Fk:getCardById(cards[1])
    local c
    if _c.name == "slash" then
      c = Fk:cloneCard("jink")
    elseif _c.name == "jink" then
      c = Fk:cloneCard("slash")
    end
    c:addSubcard(cards[1])
    return c
  end,
}
local zhaoyun = General:new(extension, "zhaoyun", "shu", 4)
zhaoyun:addSkill(longdan)
Fk:loadTranslationTable{
  ["zhaoyun"] = "赵云",
  ["longdan"] = "龙胆",
}

local mashu = fk.CreateDistanceSkill{
  name = "mashu",
  correct_func = function(self, from, to)
    if from:hasSkill(self.name) then
      return -1
    end
  end,
}
local tieqi = fk.CreateTriggerSkill{
  name = "tieqi",
  anim_type = "offensive",
  events = {fk.TargetSpecified},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      data.card.name == "slash"
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local judge = {
      who = player,
      reason = self.name,
      pattern = ".|.|heart,diamond",
    }
    room:judge(judge)
    if judge.card.color == Card.Red then
      data.disresponsive = true
    end
  end,
}
local machao = General:new(extension, "machao", "shu", 4)
machao:addSkill(mashu)
machao:addSkill(tieqi)
Fk:loadTranslationTable{
  ["machao"] = "马超",
  ["mashu"] = "马术",
  ["tieqi"] = "铁骑",
}

local jizhi = fk.CreateTriggerSkill{
  name = "jizhi",
  anim_type = "drawcard",
  events = {fk.CardUsing},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      data.card.type == Card.TypeTrick and
      data.card.sub_type ~= Card.SubtypeDelayedTrick
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, self.name)
  end,
}
local huangyueying = General:new(extension, "huangyueying", "shu", 3, 3, General.Female)
huangyueying:addSkill(jizhi)
Fk:loadTranslationTable{
  ["huangyueying"] = "黄月英",
  ["jizhi"] = "集智",
}

local zhiheng = fk.CreateActiveSkill{
  name = "zhiheng",
  anim_type = "drawcard",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name) == 0
  end,
  feasible = function(self, selected, selected_cards)
    return #selected == 0 and #selected_cards > 0
  end,
  on_effect = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    room:throwCard(effect.cards, self.name, from)
    room:drawCards(from, #effect.cards, self.name)
  end
}
local sunquan = General:new(extension, "sunquan", "wu", 4)
sunquan:addSkill(zhiheng)
Fk:loadTranslationTable{
  ["sunquan"] = "孙权",
  ["zhiheng"] = "制衡",
}

local qixi = fk.CreateViewAsSkill{
  name = "qixi",
  anim_type = "control",
  pattern = "dismantlement",
  card_filter = function(self, to_select, selected)
    if #selected == 1 then return false end
    return Fk:getCardById(to_select).color == Card.Black
  end,
  view_as = function(self, cards)
    if #cards ~= 1 then
      return nil
    end
    local c = Fk:cloneCard("dismantlement")
    c:addSubcard(cards[1])
    return c
  end,
}
local ganning = General:new(extension, "ganning", "wu", 4)
ganning:addSkill(qixi)
Fk:loadTranslationTable{
  ["ganning"] = "甘宁",
  ["qixi"] = "奇袭",
}

local keji = fk.CreateTriggerSkill{
  name = "keji",
  anim_type = "defensive",
  events = {fk.EventPhaseChanging},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      data.to == Player.Discard and
      player:usedCardTimes("slash") < 1 and
      player:getMark("_keji_played_slash") == 0
  end,
  on_use = function(self, event, target, player, data)
    return true
  end,

  refresh_events = {fk.CardResponding, fk.EventPhaseStart},
  can_refresh = function(self, event, target, player, data)
    if not (target == player and player:hasSkill(self.name)) then
      return false
    end 
    if event == fk.CardResponding then
      return data.card.name == "slash"
    elseif event == fk.EventPhaseStart then
      return player.phase == player.NotActive
    end
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    if event == fk.CardResponding then
      room:addPlayerMark(player, "_keji_played_slash", 1)
    elseif event == fk.EventPhaseStart then
      room:setPlayerMark(player, "_keji_played_slash", 0)
    end
  end
}
local lvmeng = General:new(extension, "lvmeng", "wu", 4)
lvmeng:addSkill(keji)
Fk:loadTranslationTable{
  ["lvmeng"] = "吕蒙",
  ["keji"] = "克己",
}

local kurou = fk.CreateActiveSkill{
  name = "kurou",
  anim_type = "drawcard",
  card_filter = function(self, to_select, selected, selected_targets)
    return false
  end,
  on_effect = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    room:loseHp(from, 1, self.name)
    if from:isAlive() then
      room:drawCards(from, 2, self.name)
    end
  end
}
local huanggai = General:new(extension, "huanggai", "wu", 4)
huanggai:addSkill(kurou)
Fk:loadTranslationTable{
  ["huanggai"] = "黄盖",
  ["kurou"] = "苦肉",
}

local yingzi = fk.CreateTriggerSkill{
  name = "yingzi",
  anim_type = "drawcard",
  events = {fk.DrawNCards},
  on_use = function(self, event, target, player, data)
    data.n = data.n + 1
  end,
}
local zhouyu = General:new(extension, "zhouyu", "wu", 3)
zhouyu:addSkill(yingzi)
Fk:loadTranslationTable{
  ["zhouyu"] = "周瑜",
  ["yingzi"] = "英姿",
}

local liuli = fk.CreateTriggerSkill{
  name = "liuli",
  anim_type = "defensive",
  events = {fk.TargetConfirming},
  can_trigger = function(self, event, target, player, data)
    local ret = target == player and player:hasSkill(self.name) and
      data.card.name == "slash"
    if ret then
      self.target_list = {}
      local room = player.room
      for _, p in ipairs(room:getOtherPlayers(player)) do
        if p.id ~= data.from and player:inMyAttackRange(p) then
          table.insert(self.target_list, p.id)
        end
      end
      return #self.target_list > 0
    end
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local p = room:askForChoosePlayers(player, self.target_list, 1, 1, prompt, self.name)
    if #p > 0 then
      self.cost_data = p[1]
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:doIndicate(player.id, { self.cost_data })
    data.to = self.cost_data    -- TODO
  end,
}
local daqiao = General:new(extension, "daqiao", "wu", 3, 3, General.Female)
daqiao:addSkill(liuli)
Fk:loadTranslationTable{
  ["daqiao"] = "大乔",
}

local qianxun = fk.CreateProhibitSkill{
  name = "qianxun",
  is_prohibited = function(self, from, to, card)
    if to:hasSkill(self.name) then
      return card.name == "indulgence" or card.name == "snatch"
    end
  end,
}
local luxun = General:new(extension, "luxun", "wu", 3)
luxun:addSkill(qianxun)
Fk:loadTranslationTable{
  ["luxun"] = "陆逊",
  ["qianxun"] = "谦逊",
}

local jieyin = fk.CreateActiveSkill{
  name = "jieyin",
  anim_type = "support",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name) == 0
  end,
  card_filter = function(self, to_select, selected)
    return #selected < 2 and ClientInstance:getCardArea(to_select) ~= Player.Equip
  end,
  target_filter = function(self, to_select, selected)
    local target = Fk:currentRoom():getPlayerById(to_select)
    local name = target.general
    return target:isWounded() and
      target.gender == General.Male
      and #selected < 1
  end,
  feasible = function(self, selected, selected_cards)
    return #selected == 1 and #selected_cards == 2
  end,
  on_effect = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    room:throwCard(effect.cards, self.name, from)
    room:recover({
      who = effect.tos[1],
      num = 1,
      recoverBy = effect.from,
      skillName = self.name
    })
    if from:isWounded() then
      room:recover({
        who = effect.from,
        num = 1,
        recoverBy = effect.from,
        skillName = self.name
      })
    end
   end
}
local sunshangxiang = General:new(extension, "sunshangxiang", "wu", 3, 3, General.Female)
sunshangxiang:addSkill(jieyin)
Fk:loadTranslationTable{
  ["sunshangxiang"] = "孙尚香",
  ["jieyin"] = "结姻",
}

local qingnang = fk.CreateActiveSkill{
  name = "qingnang",
  anim_type = "support",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name) == 0
  end,
  card_filter = function(self, to_select, selected, targets)
    return #selected == 0 and ClientInstance:getCardArea(to_select) ~= Player.Equip
  end,
  target_filter = function(self, to_select, selected, cards)
    return #selected == 0 and Fk:currentRoom():getPlayerById(to_select):isWounded()
  end,
  feasible = function(self, targets, cards)
    return #targets == 1 and #cards == 1
  end,
  on_effect = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    room:throwCard(effect.cards, self.name, from)
    room:recover({
      who = effect.tos[1],
      num = 1,
      recoverBy = effect.from,
      skillName = self.name
    })
  end,
}
local jijiu = fk.CreateViewAsSkill{
  name = "jijiu",
  anim_type = "support",
  pattern = "peach",
  card_filter = function(self, to_select, selected)
    if #selected == 1 then return false end
    return Fk:getCardById(to_select).color == Card.Red
  end,
  view_as = function(self, cards)
    if #cards ~= 1 then
      return nil
    end
    local c = Fk:cloneCard("peach")
    c:addSubcard(cards[1])
    return c
  end,
  enabled_at_play = function(self, player)
    return false
  end,
  enabled_at_response = function(self, player)
    return player.phase == Player.NotActive
  end,
}
local huatuo = General:new(extension, "huatuo", "qun", 3)
huatuo:addSkill(qingnang)
huatuo:addSkill(jijiu)
Fk:loadTranslationTable{
  ["huatuo"] = "华佗",
  ["qingnang"] = "青囊",
  ["jijiu"] = "急救",
}

local lvbu = General:new(extension, "lvbu", "qun", 4)
Fk:loadTranslationTable{
  ["lvbu"] = "吕布",
}

local biyue = fk.CreateTriggerSkill{
  name = "biyue",
  anim_type = "drawcard",
  events = {fk.EventPhaseStart},
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name)
      and player.phase == Player.Finish
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1)
  end,
}
local diaochan = General:new(extension, "diaochan", "qun", 3, 3, General.Female)
diaochan:addSkill(biyue)
Fk:loadTranslationTable{
  ["diaochan"] = "貂蝉",
  ["biyue"] = "闭月",
}

return extension
