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
  [":jianxiong"] = "当你受到伤害后，你可以获得对你造成伤害的牌。",
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
    local from = data.from
    return from ~= nil and
      target == player and
      target:hasSkill(self.name) and
      (not from:isNude()) and
      not target.dead
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
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
  [":guicai"] = "当一名角色的判定牌生效前，你可以打出一张手牌代替之。",
  ["#guicai-ask"] = "是否发动“鬼才”，打出一张手牌修改 %dest 的判定？",
  ["fankui"] = "反馈",
  [":fankui"] = "当你受到伤害后，你可以获得伤害来源的一张牌。",
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
    local from = data.from
    local judge = {
      who = player,
      reason = self.name,
      pattern = ".|.|spade,club,diamond",
    }
    room:judge(judge)
    if judge.card.suit ~= Card.Heart then
      local discards = room:askForDiscard(from, 2, 2, false, self.name, true)
      if #discards == 0 then
        room:damage{
          from = player,
          to = from,
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
  [":ganglie"] = "当你受到伤害后，你可以进行判定：若结果不为红桃，则伤害来源选择一项：弃置两张手牌，或受到1点伤害。",
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
  [":tuxi"] = "摸牌阶段，你可以改为获得至多两名其他角色的各一张手牌。",
  ["#tuxi-ask"] = "是否发动“突袭”，改为获得1-2名角色各一张手牌？",
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
  [":luoyi"] = "摸牌阶段，你可以少摸一张牌，若如此做，本回合你使用【杀】或【决斗】对目标角色造成伤害时，此伤害+1。",
}

local tiandu = fk.CreateTriggerSkill{
  name = "tiandu",
  events = {fk.FinishJudge},
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:obtainCard(player.id, data.card)
  end,
}
local yiji = fk.CreateTriggerSkill{
  name = "yiji",
  anim_type = "masochism",
  events = {fk.Damaged},
  on_trigger = function(self, event, target, player, data)
    self.cancel_cost = false
    for i = 1, data.damage do
      if self.cancel_cost then break end
      self:doCost(event, target, player, data)
    end
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if room:askForSkillInvoke(player, self.name, data) then
      return true
    end
    self.cancel_cost = true
  end,
  on_use = function(self, event, target, player, data)
    -- TODO: yiji logic
    player:drawCards(2)
  end,
}
local guojia = General:new(extension, "guojia", "wei", 3)
guojia:addSkill(tiandu)
guojia:addSkill(yiji)
Fk:loadTranslationTable{
  ["guojia"] = "郭嘉",
  ["tiandu"] = "天妒",
  [":tiandu"] = "当你的判定牌生效后，你可以获得之。",
  ["yiji"] = "遗计",
  [":yiji"] = "每当你受到1点伤害后，你可以观看牌堆顶的两张牌并任意分配它们。",
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
  [":luoshen"] = "准备阶段开始时，你可以进行判定：若结果为黑色，判定牌生效后你获得之，然后你可以再次发动“洛神”。",
  ["qingguo"] = "倾国",
  [":qingguo"] = "你可以将一张黑色手牌当【闪】使用或打出。",
}

local rendetrig = fk.CreateTriggerSkill{
  name = "#rendetrig",
  mute = true,
  refresh_events = {fk.EventPhaseStart},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and player.phase == Player.NotActive
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, "_rende_cards", 0)
  end,
}
local rende = fk.CreateActiveSkill{
  name = "rende",
  anim_type = "support",
  card_filter = function(self, to_select, selected)
    return ClientInstance:getCardArea(to_select) ~= Card.PlayerEquip
  end,
  target_filter = function(self, to_select, selected)
    return #selected == 0 and to_select ~= Self.id
  end,
  feasible = function(self, targets, cards)
    return #targets == 1 and #cards > 0
  end,
  on_use = function(self, room, effect)
    local target = room:getPlayerById(effect.tos[1])
    local player = room:getPlayerById(effect.from)
    local cards = effect.cards
    local marks = player:getMark("_rende_cards")
    local dummy = Fk:cloneCard'slash'
    dummy:addSubcards(cards)
    room:obtainCard(target.id, dummy, false, fk.ReasonGive)
    room:addPlayerMark(player, "_rende_cards", #cards)
    if marks < 2 and marks + #cards >= 2 and player:isWounded() then
      room:recover{
        who = player,
        num = 1,
        skillName = self.name
      }
    end
  end,
}
rende:addRelatedSkill(rendetrig)
local liubei = General:new(extension, "liubei", "shu", 4)
liubei:addSkill(rende)
Fk:loadTranslationTable{
  ["liubei"] = "刘备",
  ["rende"] = "仁德",
  [":rende"] = "出牌阶段，你可以将至少一张手牌任意分配给其他角色。你于本阶段内以此法给出的手牌首次达到两张或更多后，你回复1点体力。",
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
  [":wusheng"] = "你可以将一张红色牌当【杀】使用或打出。",
}

local paoxiaoAudio = fk.CreateTriggerSkill{
  name = "#paoxiaoAudio",
  refresh_events = {fk.CardUsing},
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and
      data.card.name == "slash" and
      player:usedCardTimes("slash") > 1
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:broadcastSkillInvoke("paoxiao")
    player.room:doAnimate("InvokeSkill", {
      name = "paoxiao",
      player = player.id,
      skill_type = "offensive",
    })
  end,
}
local paoxiao = fk.CreateTargetModSkill{
  name = "paoxiao",
  residue_func = function(self, player, skill, scope)
    if player:hasSkill(self.name) and skill.name == "slash_skill"
      and scope == Player.HistoryPhase then
      return 999
    end
  end,
}
paoxiao:addRelatedSkill(paoxiaoAudio)
local zhangfei = General:new(extension, "zhangfei", "shu", 4)
zhangfei:addSkill(paoxiao)
Fk:loadTranslationTable{
  ["zhangfei"] = "张飞",
  ["paoxiao"] = "咆哮",
  [":paoxiao"] = "锁定技，出牌阶段，你使用【杀】无次数限制。",
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
local kongchengAudio = fk.CreateTriggerSkill{
  name = "#kongchengAudio",
  refresh_events = {fk.AfterCardsMove},
  can_refresh = function(self, event, target, player, data)
    if not player:hasSkill(self.name) then return end
    if not player:isKongcheng() then return end
    for _, move in ipairs(data) do
      if move.from == player.id then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerHand then
            return true
          end
        end
      end
    end
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:broadcastSkillInvoke("kongcheng")
    player.room:doAnimate("InvokeSkill", {
      name = "kongcheng",
      player = player.id,
      skill_type = "defensive",
    })
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
kongcheng:addRelatedSkill(kongchengAudio)
local zhugeliang = General:new(extension, "zhugeliang", "shu", 3)
zhugeliang:addSkill(guanxing)
zhugeliang:addSkill(kongcheng)
Fk:loadTranslationTable{
  ["zhugeliang"] = "诸葛亮",
  ["guanxing"] = "观星",
  [":guanxing"] = "准备阶段开始时，你可以观看牌堆顶的X张牌，然后将任意数量的牌置于牌堆顶，将其余的牌置于牌堆底。（X为存活角色数且至多为5）",
  ["kongcheng"] = "空城",
  [":kongcheng"] = "锁定技，若你没有手牌，你不能被选择为【杀】或【决斗】的目标。",
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
  [":longdan"] = "你可以将一张【杀】当【闪】使用或打出，或将一张【闪】当普通【杀】使用或打出。",
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
  [":mashu"] = "锁定技。你与其他角色的距离-1。",
  ["tieqi"] = "铁骑",
  [":tieqi"] = "每当你指定【杀】的目标后，你可以进行判定：若结果为红色，该角色不能使用【闪】响应此【杀】。",
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
local qicai = fk.CreateTargetModSkill{
  name = "qicai",
  distance_limit_func =  function(self, player, skill)
    local card_name = string.sub(skill.name, 1, -7) -- assuming all card skill is named with name_skill
    local card = Fk:cloneCard(card_name)
    if player:hasSkill(self.name) and card.type == Card.TypeTrick then
      return 999
    end
  end,
}
local huangyueying = General:new(extension, "huangyueying", "shu", 3, 3, General.Female)
huangyueying:addSkill(jizhi)
huangyueying:addSkill(qicai)
Fk:loadTranslationTable{
  ["huangyueying"] = "黄月英",
  ["jizhi"] = "集智",
  [":jizhi"] = "每当你使用一张非延时锦囊牌时，你可以摸一张牌。",
  ["qicai"] = "奇才",
  [":qicai"] = "锁定技。你使用锦囊牌无距离限制。",
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
  on_use = function(self, room, effect)
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
  [":zhiheng"] = "阶段技，你可以弃置至少一张牌然后摸等量的牌。",
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
  [":qixi"] = "你可以将一张黑色牌当【过河拆桥】使用。",
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
  [":keji"] = "若你未于出牌阶段内使用或打出【杀】，你可以跳过弃牌阶段。",
}

local kurou = fk.CreateActiveSkill{
  name = "kurou",
  anim_type = "drawcard",
  card_filter = function(self, to_select, selected, selected_targets)
    return false
  end,
  on_use = function(self, room, effect)
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
  [":kurou"] = "出牌阶段，你可以失去1点体力然后摸两张牌。",
}

local yingzi = fk.CreateTriggerSkill{
  name = "yingzi",
  anim_type = "drawcard",
  events = {fk.DrawNCards},
  on_use = function(self, event, target, player, data)
    data.n = data.n + 1
  end,
}
local fanjian = fk.CreateActiveSkill{
  name = "fanjian",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name) < 1 and not player:isKongcheng()
  end,
  card_filter = function() return false end,
  target_filter = function(self, to_select, selected)
    return #selected == 0 and to_select ~= Self.id
  end,
  feasible = function(self, selected)
    return #selected == 1
  end,
  on_use = function(self, room, effect)
    local player = room:getPlayerById(effect.from)
    local target = room:getPlayerById(effect.tos[1])
    local choice = room:askForChoice(target, {"spade", "heart", "club", "diamond"}, self.name)
    local card = room:askForCardChosen(target, player, 'h', self.name)
    room:obtainCard(target.id, card, true)
    if Fk:getCardById(card):getSuitString() ~= choice then
      room:damage{
        from = player,
        to = target,
        damage = 1,
        skillName = self.name,
      }
    end
  end,
}
local zhouyu = General:new(extension, "zhouyu", "wu", 3)
zhouyu:addSkill(yingzi)
zhouyu:addSkill(fanjian)
Fk:loadTranslationTable{
  ["zhouyu"] = "周瑜",
  ["yingzi"] = "英姿",
  [":yingzi"] = "摸牌阶段，你可以多摸一张牌。",
  ["fanjian"] = "反间",
  [":fanjian"] = "阶段技。你可以令一名其他角色选择一种花色，然后正面朝上获得你的一张手牌。若此牌花色与该角色所选花色不同，你对其造成1点伤害。",
}

local guose = fk.CreateViewAsSkill{
  name = "guose",
  anim_type = "control",
  pattern = "indulgence",
  card_filter = function(self, to_select, selected)
    if #selected == 1 then return false end
    return Fk:getCardById(to_select).suit == Card.Diamond
  end,
  view_as = function(self, cards)
    if #cards ~= 1 then
      return nil
    end
    local c = Fk:cloneCard("indulgence")
    c:addSubcard(cards[1])
    return c
  end,
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
daqiao:addSkill(guose)
daqiao:addSkill(liuli)
Fk:loadTranslationTable{
  ["daqiao"] = "大乔",
  ["guose"] = "国色",
  [":guose"] = "你可以将一张方块牌当【乐不思蜀】使用。",
  ["liuli"] = "流离",
  [":liuli"] = "每当你成为【杀】的目标时，你可以弃置一张牌并选择你攻击范围内为此【杀】合法目标（无距离限制）的一名角色：若如此做，该角色代替你成为此【杀】的目标。",
}

local qianxun = fk.CreateProhibitSkill{
  name = "qianxun",
  is_prohibited = function(self, from, to, card)
    if to:hasSkill(self.name) then
      return card.name == "indulgence" or card.name == "snatch"
    end
  end,
}
local lianying = fk.CreateTriggerSkill{
  name = "lianying",
  anim_type = "drawcard",
  events = {fk.AfterCardsMove},
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(self.name) then return end
    if not player:isKongcheng() then return end
    for _, move in ipairs(data) do
      if move.from == player.id then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerHand then
            return true
          end
        end
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, self.name)
  end,
}
local luxun = General:new(extension, "luxun", "wu", 3)
luxun:addSkill(qianxun)
luxun:addSkill(lianying)
Fk:loadTranslationTable{
  ["luxun"] = "陆逊",
  ["qianxun"] = "谦逊",
  [":qianxun"] = "锁定技，你不能被选择为【顺手牵羊】与【乐不思蜀】的目标。",
  ["lianying"] = "连营",
  [":lianying"] = "每当你失去最后的手牌后，你可以摸一张牌。",
}

local xiaoji = fk.CreateTriggerSkill{
  name = "xiaoji",
  anim_type = "drawcard",
  events = {fk.AfterCardsMove},
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(self.name) then return end
    self.trigger_times = 0
    for _, move in ipairs(data) do
      if move.from == player.id then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerEquip then
            self.trigger_times = self.trigger_times + 1
          end
        end
      end
    end
    return self.trigger_times > 0
  end,
  on_trigger = function(self, event, target, player, data)
    local ret
    for i = 1, self.trigger_times do
      ret = self:doCost(event, target, player, data)
      if ret then return ret end
    end
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(2, self.name)
  end,
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
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    room:throwCard(effect.cards, self.name, from)
    room:recover({
      who = room:getPlayerById(effect.tos[1]),
      num = 1,
      recoverBy = effect.from,
      skillName = self.name
    })
    if from:isWounded() then
      room:recover({
        who = room:getPlayerById(effect.from),
        num = 1,
        recoverBy = effect.from,
        skillName = self.name
      })
    end
   end
}
local sunshangxiang = General:new(extension, "sunshangxiang", "wu", 3, 3, General.Female)
sunshangxiang:addSkill(xiaoji)
sunshangxiang:addSkill(jieyin)
Fk:loadTranslationTable{
  ["sunshangxiang"] = "孙尚香",
  ["xiaoji"] = "枭姬",
  [":xiaoji"] = "每当你失去一张装备区的装备牌后，你可以摸两张牌。",
  ["jieyin"] = "结姻",
  [":jieyin"] = "阶段技，你可以弃置两张手牌并选择一名已受伤的男性角色：若如此做，你和该角色各回复1点体力。",
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
  on_use = function(self, room, effect)
    local from = room:getPlayerById(effect.from)
    room:throwCard(effect.cards, self.name, from)
    room:recover({
      who = room:getPlayerById(effect.tos[1]),
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
  [":qingnang"] = "阶段技，你可以弃置一张手牌并选择一名已受伤的角色：若如此做，该角色回复1点体力。",
  ["jijiu"] = "急救",
  [":jijiu"] = "你的回合外，你可以将一张红色牌当【桃】使用。",
}

local lvbu = General:new(extension, "lvbu", "qun", 4)
Fk:loadTranslationTable{
  ["lvbu"] = "吕布",
}

local lijian = fk.CreateActiveSkill{
  name = "lijian",
  anim_type = "offensive",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name) == 0
  end,
  card_filter = function(self, to_select, selected)
    return #selected == 0
  end,
  target_filter = function(self, to_select, selected)
    return #selected < 2 and to_select ~= Self.id and
      ClientInstance:getPlayerById(to_select).gender == General.Male
  end,
  feasible = function(self, targets, cards)
    return #targets == 2 and #cards > 0
  end,
  on_use = function(self, room, use)
    room:throwCard(use.cards, self.name, room:getPlayerById(use.from))
    local duel = Fk:cloneCard("duel")
    local new_use = {} ---@type CardUseStruct
    new_use.from = use.tos[2]
    new_use.tos = { { use.tos[1] } }
    new_use.card = duel
    new_use.disresponsiveList = table.map(room:getAlivePlayers(), function(e)
      return e.id
    end)
    room:useCard(new_use)
  end,
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
diaochan:addSkill(lijian)
diaochan:addSkill(biyue)
Fk:loadTranslationTable{
  ["diaochan"] = "貂蝉",
  ["lijian"] = "离间",
  [":lijian"] = "阶段技，你可以弃置一张牌并选择两名其他男性角色，后选择的角色视为对先选择的角色使用了一张不能被无懈可击的决斗。",
  ["biyue"] = "闭月",
  [":biyue"] = "结束阶段开始时，你可以摸一张牌。",
}

return extension
