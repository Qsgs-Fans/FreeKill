-- SPDX-License-Identifier: GPL-3.0-or-later

Fk:loadTranslationTable({
  ["standard"] = "Standard",
  ["wei"] = "Wei",
  ["shu"] = "Shu",
  ["wu"] = "Wu",
  ["qun"] = "Qun",

  ["black"] = "Black",
  ["red"] = '<font color="#CC3131">Red</font>',
  ["nocolor"] = '<font color="grey">NoColor</font>',

  ["caocao"] = "Cao Cao",
  ["jianxiong"] = "Villainous Hero",
  [":jianxiong"] = "当你受到伤害后，你可以获得对你造成伤害的牌。",

  ["simayi"] = "Sima Yi",
  ["guicai"] = "Demonic Talent",
  [":guicai"] = "当一名角色的判定牌生效前，你可以打出一张手牌代替之。",
  ["#guicai-ask"] = "是否发动“鬼才”，打出一张手牌修改 %dest 的判定？",
  ["fankui"] = "Retaliation",
  [":fankui"] = "当你受到伤害后，你可以获得伤害来源的一张牌。",

  ["xiahoudun"] = "Xiahou Dun",
  ["ganglie"] = "Unyielding",
  [":ganglie"] = "当你受到伤害后，你可以进行判定：若结果不为红桃，则伤害来源选择一项：弃置两张手牌，或受到1点伤害。",

  ["zhangliao"] = "Zhang Liao",
  ["tuxi"] = "Sudden Strike",
  [":tuxi"] = "摸牌阶段，你可以改为获得至多两名其他角色的各一张手牌。",
  ["#tuxi-ask"] = "是否发动“突袭”，改为获得1-2名角色各一张手牌？",

  ["xuchu"] = "Xu Chu",
  ["luoyi"] = "Bare Chested",
  [":luoyi"] = "摸牌阶段，你可以少摸一张牌，若如此做，本回合你使用【杀】或【决斗】对目标角色造成伤害时，此伤害+1。",

  ["guojia"] = "Guo Jia",
  ["tiandu"] = "Envy of Heaven",
  [":tiandu"] = "当你的判定牌生效后，你可以获得之。",
  ["yiji"] = "Bequeathed Strategy",
  [":yiji"] = "每当你受到1点伤害后，你可以观看牌堆顶的两张牌并任意分配它们。",
  ["yiji_active"] = "Bequeathed Strategy",
  ["#yiji-give"] = "Bequeathed Strategy: You may distribute these cards to any players, or click Cancel to reserve",

  ["zhenji"] = "Zhen Ji",
  ["luoshen"] = "Goddess Luo",
  [":luoshen"] = "准备阶段开始时，你可以进行判定：若结果为黑色，判定牌生效后你获得之，然后你可以再次发动“洛神”。",
  ["qingguo"] = "Helen of Troy",
  [":qingguo"] = "你可以将一张黑色手牌当【闪】使用或打出。",

  ["liubei"] = "Liu Bei",
  ["rende"] = "Benevolence",
  [":rende"] = "出牌阶段，你可以将至少一张手牌任意分配给其他角色。你于本阶段内以此法给出的手牌首次达到两张或更多后，你回复1点体力。",

  ["guanyu"] = "Guan Yu",
  ["wusheng"] = "Warrior Saint",
  [":wusheng"] = "你可以将一张红色牌当【杀】使用或打出。",

  ["zhangfei"] = "Zhang Fei",
  ["paoxiao"] = "Roar",
  [":paoxiao"] = "锁定技，出牌阶段，你使用【杀】无次数限制。",

  ["zhugeliang"] = "Zhuge Liang",
  ["guanxing"] = "Stargaze",
  [":guanxing"] = "准备阶段开始时，你可以观看牌堆顶的X张牌，然后将任意数量的牌置于牌堆顶，将其余的牌置于牌堆底。（X为存活角色数且至多为5）",
  ["kongcheng"] = "Empty Fort",
  [":kongcheng"] = "锁定技，若你没有手牌，你不能被选择为【杀】或【决斗】的目标。",

  ["zhaoyun"] = "Zhao Yun",
  ["longdan"] = "Dragon Heart",
  [":longdan"] = "你可以将一张【杀】当【闪】使用或打出，或将一张【闪】当普通【杀】使用或打出。",

  ["machao"] = "Ma Chao",
  ["mashu"] = "Horsemanship",
  [":mashu"] = "锁定技。你与其他角色的距离-1。",
  ["tieqi"] = "Iron Cavalry",
  [":tieqi"] = "每当你指定【杀】的目标后，你可以进行判定：若结果为红色，该角色不能使用【闪】响应此【杀】。",

  ["huangyueying"] = "Huang Yueying",
  ["jizhi"] = "Wisdom",
  [":jizhi"] = "每当你使用一张非延时锦囊牌时，你可以摸一张牌。",
  ["qicai"] = "Genius",
  [":qicai"] = "锁定技。你使用锦囊牌无距离限制。",

  ["sunquan"] = "Sun Quan",
  ["zhiheng"] = "Balance of Power",
  [":zhiheng"] = "阶段技，你可以弃置至少一张牌然后摸等量的牌。",

  ["ganning"] = "Gan Ning",
  ["qixi"] = "Surprise Raid",
  [":qixi"] = "你可以将一张黑色牌当【过河拆桥】使用。",

  ["lvmeng"] = "Lv Meng",
  ["keji"] = "Self Mastery",
  [":keji"] = "若你未于出牌阶段内使用或打出【杀】，你可以跳过弃牌阶段。",

  ["huanggai"] = "Huang Gai",
  ["kurou"] = "Self Injury",
  [":kurou"] = "出牌阶段，你可以失去1点体力然后摸两张牌。",

  ["zhouyu"] = "Zhou Yu",
  ["yingzi"] = "Handsome",
  [":yingzi"] = "摸牌阶段，你可以多摸一张牌。",
  ["fanjian"] = "Sow Dissension",
  [":fanjian"] = "阶段技。你可以令一名其他角色选择一种花色，然后正面朝上获得你的一张手牌。若此牌花色与该角色所选花色不同，你对其造成1点伤害。",

  ["daqiao"] = "Da Qiao",
  ["guose"] = "National Beauty",
  [":guose"] = "你可以将一张方块牌当【乐不思蜀】使用。",
  ["liuli"] = "Shirk",
  [":liuli"] = "每当你成为【杀】的目标时，你可以弃置一张牌并选择你攻击范围内为此【杀】合法目标（无距离限制）的一名角色：若如此做，该角色代替你成为此【杀】的目标。",
  ["#liuli-target"] = "流离：你可以弃置一张牌，将【杀】的目标转移给一名其他角色",

  ["luxun"] = "Lu Xun",
  ["qianxun"] = "Humility",
  [":qianxun"] = "锁定技，你不能被选择为【顺手牵羊】与【乐不思蜀】的目标。",
  ["lianying"] = "One After Another",
  [":lianying"] = "每当你失去最后的手牌后，你可以摸一张牌。",

  ["sunshangxiang"] = "Sun Shangxiang",
  ["xiaoji"] = "Warrior Lady",
  [":xiaoji"] = "每当你失去一张装备区的装备牌后，你可以摸两张牌。",
  ["jieyin"] = "Marriage",
  [":jieyin"] = "阶段技，你可以弃置两张手牌并选择一名已受伤的男性角色：若如此做，你和该角色各回复1点体力。",

  ["huatuo"] = "Hua Tuo",
  ["qingnang"] = "Green Salve",
  [":qingnang"] = "阶段技，你可以弃置一张手牌并选择一名已受伤的角色：若如此做，该角色回复1点体力。",
  ["jijiu"] = "First Aid",
  [":jijiu"] = "你的回合外，你可以将一张红色牌当【桃】使用。",

  ["lvbu"] = "Lv Bu",

  ["diaochan"] = "Diao Chan",
  ["lijian"] = "Seed of Animosity",
  [":lijian"] = "阶段技，你可以弃置一张牌并选择两名其他男性角色，后选择的角色视为对先选择的角色使用了一张不能被无懈可击的决斗。",
  ["biyue"] = "Envious by Moon",
  [":biyue"] = "结束阶段开始时，你可以摸一张牌。",
}, "en_US")

-- aux skills
Fk:loadTranslationTable({
  ["discard_skill"] = "Discard",
  ["choose_players_skill"] = "Choose players",
}, "en_US")
