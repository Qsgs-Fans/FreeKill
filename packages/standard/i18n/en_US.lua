-- SPDX-License-Identifier: GPL-3.0-or-later

Fk:loadTranslationTable({
  ["standard"] = "Standard",
  ["wei"] = "*Wei*",
  ["shu"] = "*Shu*",
  ["wu"] = "*Wu*",
  ["qun"] = "*Neutral*",

  ["caocao"] = "Cao Cao",
  ["jianxiong"] = "Villainous Hero",
  [":jianxiong"] = "After you suffer DMG: you can take the card(s) that caused it.",
  ["hujia"] = "Royal Escort",
  [":hujia"] = "(lord) When you need to use/play Dodge: you can ask other Wei characters to play Dodge, which is regard as you use/play that.",
  ["#hujia-ask"] = "Royal Escort: you can play a Dodge, which is regarded as %src uses/plays",

  ["simayi"] = "Sima Yi",
  ["guicai"] = "Demonic Talent",
  [":guicai"] = "When a player performs a judgement, before it takes effect: you can play a hand card. It becomes the judgement result.",
  ["#guicai-ask"] = "Demonic Talent: you can play a hand card to retrial the judgement of %dest",
  ["fankui"] = "Retaliation",
  [":fankui"] = "After you suffer DMG: you can take 1 card from the damage source.",

  ["xiahoudun"] = "Xiahou Dun",
  ["ganglie"] = "Eye for an Eye",
  [":ganglie"] = "After you suffer DMG: you can perform a judgment; if it's not heart, the DMG source must choose: 1. Suffer 1 DMG from you. 2. Discard 2 hand cards.",

  ["zhangliao"] = "Zhang Liao",
  ["tuxi"] = "Sudden Strike",
  [":tuxi"] = "During your draw phase, you can change to take 1 hand card from up to 2 players.",
  ["#tuxi-ask"] = "Sudden Strike: you can change draw card to take 1 hand card from up to 2 players",

  ["xuchu"] = "Xu Chu",
  ["luoyi"] = "Bare Chested",
  [":luoyi"] = "In your draw phase, you can draw 1 fewer card. In this turn, the DMG of your Slash and Duel is increased by +1.",

  ["guojia"] = "Guo Jia",
  ["tiandu"] = "Envy of Heaven",
  [":tiandu"] = "After your judgement takes effect: you can take the result card.",
  ["yiji"] = "Bequeathed Strategy",
  [":yiji"] = "After you suffer 1 DMG: you can look at the top 2 cards of the draw pile; then, you can distribute them to any player(s).",
  ["yiji_active"] = "Bequeathed Strategy",
  ["#yiji-give"] = "Bequeathed Strategy: You may distribute these cards to any players, or click Cancel to reserve",

  ["zhenji"] = "Zhen Ji",
  ["luoshen"] = "Goddess Luo",
  [":luoshen"] = 'In your prepare phase: you can perform a judgment; if it\'s black, you get the card and you can activate "Goddess Luo" again.',
  ["#luoshen_obtain"] = "Goddess Luo",
  ["qingguo"] = "Helen of Troy",
  [":qingguo"] = "You can use/play any black hand card as Dodge.",

  ["liubei"] = "Liu Bei",
  ["rende"] = "Benevolence",
  [":rende"] = "In your Action Phase: you can give any # of hand cards to other players; then, if you have given a total of 2 or more cards, you heal 1 HP (only once).",
  ["#rende-active"] = "Use Benevolence, give any # of hand cards to other players;<br >then, if you have given a total of 2 or more cards, you heal 1 HP (only once)",
  ["jijiang"] = "Rouse",
  [":jijiang"] = "(lord) When you need to use/play Slash: you can ask other Shu characters to play Slash, which is regard as you use/play that.",
  ["#jijiang-ask"] = "Rouse: you can play a Slash, which is regarded as %src uses/plays",

  ["guanyu"] = "Guan Yu",
  ["wusheng"] = "Warrior Saint",
  [":wusheng"] = "You can use/play any red card as Slash.",
  ["#wusheng"] = "Use Warrior Saint to use/play any red card as Slash.",

  ["zhangfei"] = "Zhang Fei",
  ["paoxiao"] = "Roar",
  [":paoxiao"] = "(forced) You can use any # of Slash.",

  ["zhugeliang"] = "Zhuge Liang",
  ["guanxing"] = "Stargaze",
  [":guanxing"] = "In your Beginning Phase: you can examine X cards from the deck; then, you can place any # of them at the top of the deck and the rest at the bottom. (X = # of living players, max. 5)",
  ["kongcheng"] = "Empty Fort",
  [":kongcheng"] = "(forced) If you don’t have hand cards, you cannot be the target of Sha or Duel.",

  ["zhaoyun"] = "Zhao Yun",
  ["longdan"] = "Dragon Heart",
  [":longdan"] = "You can use/play Slash as Dodge. You can use/play Dodge as Slash.",
  ["#longdan"] = "Use Dragon Heart to use/play Slash as Dodge, or use/play Dodge as Slash.",

  ["machao"] = "Ma Chao",
  ["mashu"] = "Horsemanship",
  [":mashu"] = "(forced) The distance from you to other players is reduced by -1.",
  ["tieqi"] = "Iron Cavalry",
  [":tieqi"] = "After you use Slash to target a player: you can perform a judgment; if it’s red, he can't use Dodge.",

  ["huangyueying"] = "Huang Yueying",
  ["jizhi"] = "Wisdom",
  [":jizhi"] = "When you use a non-delay trick card, you can draw 1 card.",
  ["qicai"] = "Genius",
  [":qicai"] = "(forced) Your trick cards have unlimited range.",

  ["sunquan"] = "Sun Quan",
  ["zhiheng"] = "Balance of Power",
  [":zhiheng"] = "Once per Action Phase: you can discard any # of cards; then, draw the same # of cards.",
  ["#zhiheng-active"] = "Use Balance of Power, discard any # of cards; then, draw the same # of cards",
  ["jiuyuan"] = "Rescued",
  [":jiuyuan"] = "(lord, forced) When another Wu character uses Peach to you, you heal +1 HP.",

  ["ganning"] = "Gan Ning",
  ["qixi"] = "Surprise Raid",
  [":qixi"] = "You can use any black card as Dismantlement.",

  ["lvmeng"] = "Lü Meng",
  ["keji"] = "Self Mastery",
  [":keji"] = "If you haven't used/played Slash in your Action Phase, you can skip your Discard Phase.",

  ["huanggai"] = "Huang Gai",
  ["kurou"] = "Trojan Flesh",
  [":kurou"] = "In your Action Phase: you can lose 1 HP; then, draw 2 cards.",
  ["#kurou-active"] = "Use Trojan Flesh, lose 1 HP; then, draw 2 cards",

  ["zhouyu"] = "Zhou Yu",
  ["yingzi"] = "Handsome",
  [":yingzi"] = "In your Draw Phase: you can draw +1 additional card.",
  ["fanjian"] = "Sow Dissension",
  [":fanjian"] = "Once per Action Phase: you can make another player choose 1 suit; then, he takes 1 hand card from you and displays it. If the guess was wrong, you cause him 1 DMG.",
  ["#fanjian-active"] = "Use Sow Dissension, select another player; he chooses 1 suit;<br />then he takes 1 hand card from you and displays it. If the guess was wrong, you cause him 1 DMG",

  ["daqiao"] = "Da Qiao",
  ["guose"] = "National Beauty",
  [":guose"] = "You can use any diamond card as Indulgence.",
  ["#guose"] = "Use National Beauty to use any diamond card as Indulgence",
  ["liuli"] = "Shirk",
  [":liuli"] = "When you become the target of Slash: you can discard 1 card and select another player (except the attacker) within your attack range; then, he becomes the target of the Slash instead.",
  ["#liuli-target"] = "Shirk: you can discard 1 card and transfer the Slash",

  ["luxun"] = "Lu Xun",
  ["qianxun"] = "Humility",
  [":qianxun"] = "(forced) You can't be the target of Snatch or Indulgence.",
  ["lianying"] = "One After Another",
  [":lianying"] = "When you lose your last hand card: you can draw 1 card.",

  ["sunshangxiang"] = "Sun Shangxiang",
  ["xiaoji"] = "Warrior Lady",
  [":xiaoji"] = "After you lose 1 card in your equipment area: you can draw 2 cards.",
  ["jieyin"] = "Marriage",
  [":jieyin"] = "Once per Action Phase: you can discard 2 hand cards and select a hurt male character; then, both of you heal 1 HP.",
  ["#jieyin-active"] = "Use Marriage, discard 2 hand cards and select a hurt male character; then, both of you heal 1 HP",

  ["huatuo"] = "Hua Tuo",
  ["qingnang"] = "Green Salve",
  [":qingnang"] = "Once per Action Phase: you can discard 1 hand card and select a wounded player; then, he heals 1 HP.",
  ["#qingnang-active"] = "Use Green Salve, discard 1 hand card and select a wounded player; then, he heals 1 HP",
  ["jijiu"] = "First Aid",
  [":jijiu"] = "Outside of your turn: you can use any red card as Peach.",
  ["#jijiu"] = "Use First Aid, use any red card as Peach",

  ["lvbu"] = "Lü Bu",
  ["wushuang"] = "Without Equal",
  [":wushuang"] = "(forced) If you use Slash to target a player, the target needs to use 2 Dodge to evade it. During Duel, the opponent must play 2 Slash per round.",

  ["diaochan"] = "Diao Chan",
  ["lijian"] = "Seed of Animosity",
  [":lijian"] = "Once per Action Phase: you may discard 1 card and select 2 male characters; then, this is regarded as one of them having used Duel to target the other. This Duel can't be countered by Nullification.",
  ["#lijian-active"] = "Use Seed of Animosity, discard 1 card and select 2 male characters;<br />then, this is regarded as one of them having used Duel to target the other.<br />This Duel can't be countered by Nullification",
  ["biyue"] = "Envious by Moon",
  [":biyue"] = "In your Finish Phase, you can draw 1 card.",

  ["fastchat_m"] = "quick chats",
  ["fastchat_f"] = "quick chats",

  ["$fastchat_m1"] = "能不能快一点啊，兵贵神速啊。",
  ["$fastchat_m2"] = "主公，别开枪，自己人！",
  ["$fastchat_m3"] = "小内再不跳，后面还怎么玩啊？",
  ["$fastchat_m4"] = "你们忍心，就这么让我酱油了？",
  ["$fastchat_m5"] = "我……我惹你们了吗！？",
  ["$fastchat_m6"] = "姑娘，你真是条汉子。",
  ["$fastchat_m7"] = "三十六计走为上，容我去去便回。",
  ["$fastchat_m8"] = "人心散了，队伍不好带啊。",
  ["$fastchat_m9"] = "昏君，昏君呐！",
  ["$fastchat_m10"] = "风吹鸡蛋壳，牌去人安乐。",
  ["$fastchat_m11"] = "小内啊，你老悠着点。",
  ["$fastchat_m12"] = "啊，不好意思，刚才卡了。",
  ["$fastchat_m13"] = "你可以打的再烂一点吗？",
  ["$fastchat_m14"] = "哥们，给力点行吗？",
  ["$fastchat_m15"] = "哥哥，交个朋友吧。",
  ["$fastchat_m16"] = "妹子，交个朋友吧。",
  ["$fastchat_m17"] = "我从未见过如此厚颜无耻之人！",
  ["$fastchat_m18"] = "你随便杀，闪不了算我输。",
  ["$fastchat_m19"] = "这波，不亏。",
  ["$fastchat_m20"] = "请收下我的膝盖。",
  ["$fastchat_m21"] = "你咋不上天呢？",
  ["$fastchat_m22"] = "放开我的队友，冲我来。",
  ["$fastchat_m23"] = "见证奇迹的时刻到了。",
  ["$fastchat_f1"] = "能不能快一点啊，兵贵神速啊。",
  ["$fastchat_f2"] = "主公，别开枪，自己人！",
  ["$fastchat_f3"] = "小内再不跳，后面还怎么玩啊？",
  ["$fastchat_f4"] = "嗯嘛~你们忍心，就这么让我酱油了？",
  ["$fastchat_f5"] = "我……我惹你们了吗？",
  ["$fastchat_f6"] = "姑娘，你真是条汉子。",
  ["$fastchat_f7"] = "三十六计走为上，容我去去便回。",
  ["$fastchat_f8"] = "人心散了，队伍不好带啊。",
  ["$fastchat_f9"] = "昏君，昏君呐！",
  ["$fastchat_f10"] = "风吹鸡蛋壳，牌去人安乐。",
  ["$fastchat_f11"] = "小内啊，你老悠着点儿。",
  ["$fastchat_f12"] = "不好意思，刚才卡了。",
  ["$fastchat_f13"] = "你可以打的再烂一点吗？",
  ["$fastchat_f14"] = "哥们，给力点行吗？",
  ["$fastchat_f15"] = "哥，交个朋友吧。",
  ["$fastchat_f16"] = "妹子，交个朋友吧。",
  ["$fastchat_f17"] = "我从未见过如此厚颜无耻之人！",
  ["$fastchat_f18"] = "你随便杀，闪不了算我输。",
  ["$fastchat_f19"] = "这波，不亏。",
  ["$fastchat_f20"] = "请收下我的膝盖。",
  ["$fastchat_f21"] = "你咋不上天呢？",
  ["$fastchat_f22"] = "放开我的队友，冲我来。",
  ["$fastchat_f23"] = "见证奇迹的时刻到了。",

  ["aaa_role_mode"] = "Role mode",
  [":aaa_role_mode"] = [[
  There should be some text to introduce rule of role mode, buy currently have nothing.
  ]],
}, "en_US")

-- aux skills
Fk:loadTranslationTable({
  ["discard_skill"] = "Discard",
  ["choose_cards_skill"] = "Choose card",
  ["choose_players_skill"] = "Choose players",
  ["ex__choose_skill"] = "Choose",
  ["distribution_select_skill"] = "Distribute",
  ["choose_players_to_move_card_in_board"] = "Choose players",
  ["userealcard_skill"] = "Use",
  ["virtual_viewas"] = "Use",

  ["reveal_skill&"] = "Reveal",
  ["#reveal_skill&"] = "Choose a character to reveal",
  [":reveal_skill&"] = "In action phase, you can reveal a character who has Forced skills.",
  ["revealMain"] = "Reveal main character %arg",
  ["revealDeputy"] = "Reveal deputy character %arg",

  ["game_rule"] = "GameRule",
}, "en_US")

-- init
Fk:loadTranslationTable({
  ["left lord and loyalist alive"] = "You're the only surviving Renegade and all others alive are lord and loyalists.",
  ["left one rebel alive"] = "You're the only surviving Rebel and there's no surviving Renegade.",
  ["left you alive"] = "No surviving loyalists and only another fraction remains.",
  ["loyalist never surrender"] = "Loyalist never surrender!",

  ["anjiang"] = "Hidden Char.",
}, "en_US")
