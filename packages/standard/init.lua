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

local caocao = General:new(extension, "caocao", "wei", 4)
Fk:loadTranslationTable{
  ["caocao"] = "曹操",
}

local fankui = fk.CreateTriggerSkill{
  name = "fankui",
  events = {fk.Damaged},
  frequency = Skill.NotFrequent,
  can_trigger = function(self, event, target, player, data)
    local room = target.room
    local from = room:getPlayerById(data.from)
    return from ~= nil and
      target == player and
      target:hasSkill(self.name)
  end,
  on_trigger = function(self, event, target, player, data)
    local room = player.room
    local from = room:getPlayerById(data.from)
    if (not from) or from:isNude() then return false end
    if room:askForSkillInvoke(player, self.name) then
      local card = room:askForCardChosen(player, from, "he", self.name)
      room:obtainCard(player.id, card, false, fk.ReasonPrey)
    end
  end
}
local simayi = General:new(extension, "simayi", "wei", 3)
simayi:addSkill(fankui)
Fk:loadTranslationTable{
  ["simayi"] = "司马懿",
  ["fankui"] = "反馈",
}

local xiahoudun = General:new(extension, "xiahoudun", "wei", 4)
Fk:loadTranslationTable{
  ["xiahoudun"] = "夏侯惇",
}

local zhangliao = General:new(extension, "zhangliao", "wei", 4)
Fk:loadTranslationTable{
  ["zhangliao"] = "张辽",
}

local xuchu = General:new(extension, "xuchu", "wei", 4)
Fk:loadTranslationTable{
  ["xuchu"] = "许褚",
}

local guojia = General:new(extension, "guojia", "wei", 3)
Fk:loadTranslationTable{
  ["guojia"] = "郭嘉",
}

local zhenji = General:new(extension, "zhenji", "wei", 3, 3, General.Female)
Fk:loadTranslationTable{
  ["zhenji"] = "甄姬",
}

local liubei = General:new(extension, "liubei", "shu", 4)
Fk:loadTranslationTable{
  ["liubei"] = "刘备",
}

local wusheng = fk.CreateViewAsSkill{
  name = "wusheng",
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

local zhugeliang = General:new(extension, "zhugeliang", "shu", 3)
Fk:loadTranslationTable{
  ["zhugeliang"] = "诸葛亮",
}

local zhaoyun = General:new(extension, "zhaoyun", "shu", 4)
Fk:loadTranslationTable{
  ["zhaoyun"] = "赵云",
}

local mashu = fk.CreateDistanceSkill{
  name = "mashu",
  correct_func = function(self, from, to)
    if from:hasSkill(self.name) then
      return -1
    end
  end,
}
local machao = General:new(extension, "machao", "shu", 4)
machao:addSkill(mashu)
Fk:loadTranslationTable{
  ["machao"] = "马超",
  ["mashu"] = "马术",
}

local huangyueying = General:new(extension, "huangyueying", "shu", 3, 3, General.Female)
Fk:loadTranslationTable{
  ["huangyueying"] = "黄月英",
}

local zhiheng = fk.CreateActiveSkill{
  name = "zhiheng",
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

local ganning = General:new(extension, "ganning", "wu", 4)
Fk:loadTranslationTable{
  ["ganning"] = "甘宁",
}

local lvmeng = General:new(extension, "lvmeng", "wu", 4)
Fk:loadTranslationTable{
  ["lvmeng"] = "吕蒙",
}

local kurou = fk.CreateActiveSkill{
  name = "kurou",
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

local zhouyu = General:new(extension, "zhouyu", "wu", 3)
Fk:loadTranslationTable{
  ["zhouyu"] = "周瑜",
}

local daqiao = General:new(extension, "daqiao", "wu", 3, 3, General.Female)
Fk:loadTranslationTable{
  ["daqiao"] = "大乔",
}

local luxun = General:new(extension, "luxun", "wu", 3)
Fk:loadTranslationTable{
  ["luxun"] = "陆逊",
}

local jieyin = fk.CreateActiveSkill{
  name = "jieyin",
  card_filter = function(self, to_select, selected)
    return #selected < 2  -- TODO:choose equip
  end,
  target_filter = function(self, to_select, selected)
    local target = Fk:currentRoom():getPlayerById(to_select)
    local name = target.general
    return target:isWounded() and
      Fk.generals[name].gender == General.Male
      and #selected < 1
      -- and not target:hasSkill(self.name)
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

local huatuo = General:new(extension, "huatuo", "qun", 3)
Fk:loadTranslationTable{
  ["huatuo"] = "华佗",
}

local lvbu = General:new(extension, "lvbu", "qun", 4)
Fk:loadTranslationTable{
  ["lvbu"] = "吕布",
}

local diaochan = General:new(extension, "diaochan", "qun", 3, 3, General.Female)
Fk:loadTranslationTable{
  ["diaochan"] = "貂蝉",
}

return extension
