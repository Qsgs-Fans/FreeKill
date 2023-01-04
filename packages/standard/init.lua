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

local caocao = General:new(extension, "caocao", "wei", 4)
Fk:loadTranslationTable{
  ["caocao"] = "曹操",
}

local simayi = General:new(extension, "simayi", "wei", 3)
Fk:loadTranslationTable{
  ["simayi"] = "司马懿",
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

local zhenji = General:new(extension, "zhenji", "wei", 3)
Fk:loadTranslationTable{
  ["zhenji"] = "甄姬",
}

local liubei = General:new(extension, "liubei", "shu", 4)
Fk:loadTranslationTable{
  ["liubei"] = "刘备",
}

local guanyu = General:new(extension, "guanyu", "shu", 4)
Fk:loadTranslationTable{
  ["guanyu"] = "关羽",
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

local huangyueying = General:new(extension, "huangyueying", "shu", 3)
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

local huanggai = General:new(extension, "huanggai", "wu", 4)
Fk:loadTranslationTable{
  ["huanggai"] = "黄盖",
}

local zhouyu = General:new(extension, "zhouyu", "wu", 3)
Fk:loadTranslationTable{
  ["zhouyu"] = "周瑜",
}

local daqiao = General:new(extension, "daqiao", "wu", 3)
Fk:loadTranslationTable{
  ["daqiao"] = "大乔",
}

local luxun = General:new(extension, "luxun", "wu", 3)
Fk:loadTranslationTable{
  ["luxun"] = "陆逊",
}

local sunshangxiang = General:new(extension, "sunshangxiang", "wu", 3)
Fk:loadTranslationTable{
  ["sunshangxiang"] = "孙尚香",
}

local huatuo = General:new(extension, "huatuo", "qun", 3)
Fk:loadTranslationTable{
  ["huatuo"] = "华佗",
}

local lvbu = General:new(extension, "lvbu", "qun", 4)
Fk:loadTranslationTable{
  ["lvbu"] = "吕布",
}

local diaochan = General:new(extension, "diaochan", "qun", 3)
Fk:loadTranslationTable{
  ["diaochan"] = "貂蝉",
}

return extension
