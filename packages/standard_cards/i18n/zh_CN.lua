-- SPDX-License-Identifier: GPL-3.0-or-later

Fk:loadTranslationTable{
  ["standard_cards"] = "标+EX",

  ["unknown_card"] = '<font color="#B5BA00"><b>未知牌</b></font>',
  ["log_spade"] = '♠',
  ["log_heart"] = '<font color="#CC3131">♥</font>',
  ["log_club"] = '♣',
  ["log_diamond"] = '<font color="#CC3131">♦</font>',
  ["log_nosuit"] = "无花色",
  ["spade"] = "黑桃",
  ["heart"] = "红桃",
  ["club"] = "梅花",
  ["diamond"] = "方块",
  ["nosuit"] = "无花色",
  ["black"] = '黑色',
  ["red"] = '<font color="#CC3131">红色</font>',
  ["nocolor"] = '<font color="grey">无色</font>',
  ["suit"] = "花色",
  ["color"] = "颜色",
  ["number"] = "点数",

  ["basic_char"] = "基",
  ["trick_char"] = "锦",
  ["equip_char"] = "装",

  ["basic"] = "基本牌",
  ["trick"] = "锦囊牌",
  ["equip"] = "装备牌",
  ["weapon"] = "武器牌",
  ["armor"] = "防具牌",
  ["defensive_horse"] = "防御坐骑牌",
  ["defensive_ride"] = "防御坐骑牌",
  ["offensive_horse"] = "进攻坐骑牌",
  ["offensive_ride"] = "进攻坐骑牌",
  ["equip_horse"] = "坐骑牌",
  ["treasure"] = "宝物牌",
  ["delayed_trick"] = "延时类锦囊牌",
  ["damage_card-"] = "伤害类",
  ["multiple_targets-"] = "多目标",

  ["type_weapon"] = "武器",
  ["type_armor"] = "防具",
  ["type_defensive_horse"] = "防御坐骑",
  ["type_offensive_horse"] = "进攻坐骑",
  ["type_horse"] = "坐骑",

  ["method_use"] = "使用",
  ["method_response_play"] = "打出",
  ["method_response"] = "响应",
  ["method_draw"] = "摸",
  ["method_discard"] = "弃置",

  ["prohibit"] = "禁",

  ["slash"] = "杀",
  [":slash"] = "基本牌<br /><b>时机</b>：出牌阶段<br /><b>目标</b>：攻击范围内的一名角色<br /><b>效果</b>：对目标角色造成1点伤害。",
  ["#slash-jink"] = "%src 对你使用了【杀】，请使用一张【闪】",
  ["#slash-jink-multi"] = "%src 对你使用了【杀】，请使用一张【闪】（此为第 %arg 张，共需 %arg2 张）",
  ["#slash_skill"] = "选择攻击范围内的一名角色，对其造成1点伤害",
  ["#slash_skill_multi"] = "选择攻击范围内的至多%arg名角色，对这些角色各造成1点伤害",

  ["jink"] = "闪",
  [":jink"] = "基本牌<br /><b>时机</b>：【杀】对你生效时<br /><b>目标</b>：此【杀】<br /><b>效果</b>：抵消此【杀】的效果。",

  ["peach"] = "桃",
  [":peach"] = "基本牌<br /><b>时机</b>：出牌阶段/一名角色处于濒死状态时<br /><b>目标</b>：已受伤的你/处于濒死状态的角色<br /><b>效果</b>：目标角色回复1点体力。",
  ["#peach_skill"] = "你回复1点体力",

  ["dismantlement"] = "过河拆桥",
  [":dismantlement"] = "锦囊牌<br /><b>时机</b>：出牌阶段<br /><b>目标</b>：一名区域内有牌的其他角色。<br /><b>效果</b>：你弃置目标角色区域内的一张牌。",
  ["dismantlement_skill"] = "过河拆桥",
  ["#dismantlement_skill"] = "选择一名区域内有牌的其他角色，你弃置其区域内的一张牌",

  ["snatch"] = "顺手牵羊",
  [":snatch"] = "锦囊牌<br /><b>时机</b>：出牌阶段<br /><b>目标</b>：距离1的一名区域内有牌的角色<br /><b>效果</b>：你获得目标角色区域内的一张牌。",
  ["snatch_skill"] = "顺手牵羊",
  ["#snatch_skill"] = "选择距离1的区域内有牌的角色，你获得其区域内的一张牌",

  ["duel"] = "决斗",
  [":duel"] = "锦囊牌<br /><b>时机</b>：出牌阶段<br /><b>目标</b>：一名其他角色<br /><b>效果</b>：由目标角色开始，其与你轮流打出一张【杀】，直到其与你中的一名角色未打出【杀】。未打出【杀】的角色受到其与你中的另一名角色造成的1点伤害。",
  ["#duel_skill"] = "选择一名其他角色，由其开始，其与你轮流打出一张【杀】，直到其与你中的一名角色未打出【杀】。<br />未打出【杀】的角色受到其与你中的另一名角色造成的1点伤害",

  ["collateral"] = "借刀杀人",
  [":collateral"] = "锦囊牌<br /><b>时机</b>：出牌阶段<br /><b>目标</b>：装备区里有武器牌且攻击范围内有【杀】的合法目标的一名其他角色A（你需要选择一名A攻击范围内的【杀】的合法目标B）<br /><b>效果</b>：A需对B使用一张【杀】，否则将装备区里的武器牌交给你。",
  ["#collateral-slash"] = "借刀杀人：你需对 %dest 使用【杀】，否则将你的装备区里的武器牌交给 %src",
  ["#collateral_skill"] = "选择装备区里有武器牌且攻击范围内有【杀】的合法目标的一名其他角色A，<br />再选择一名A攻击范围内的【杀】的合法目标B。A需对B使用【杀】，否则将装备区里的武器牌交给你",

  ["ex_nihilo"] = "无中生有",
  [":ex_nihilo"] = "锦囊牌<br /><b>时机</b>：出牌阶段<br /><b>目标</b>：你<br /><b>效果</b>：目标角色摸两张牌。",
  ["#ex_nihilo_skill"] = "你摸两张牌",

  ["nullification"] = "无懈可击",
  [":nullification"] = "锦囊牌<br /><b>时机</b>：锦囊牌对目标角色生效前，或一张【无懈可击】生效前<br /><b>目标</b>：该锦囊牌<br /><b>效果</b>：抵消该锦囊牌对该角色产生的效果，或抵消另一张【无懈可击】产生的效果。",

  ["savage_assault"] = "南蛮入侵",
  [":savage_assault"] = "锦囊牌<br /><b>时机</b>：出牌阶段<br /><b>目标</b>：所有其他角色<br /><b>效果</b>：每名目标角色需打出一张【杀】，否则受到1点伤害。",
  ["#savage_assault_skill"] = "所有其他角色需打出一张【杀】，否则受到1点伤害",

  ["archery_attack"] = "万箭齐发",
  [":archery_attack"] = "锦囊牌<br /><b>时机</b>：出牌阶段<br /><b>目标</b>：所有其他角色<br /><b>效果</b>：每名目标角色需打出一张【闪】，否则受到1点伤害。",
  ["#archery_attack_skill"] = "所有其他角色需打出一张【闪】，否则受到1点伤害",

  ["god_salvation"] = "桃园结义",
  [":god_salvation"] = "锦囊牌<br /><b>时机</b>：出牌阶段<br /><b>目标</b>：所有角色<br /><b>效果</b>：每名目标角色回复1点体力。",
  ["#god_salvation_skill"] = "所有角色回复1点体力",

  ["amazing_grace"] = "五谷丰登",
  [":amazing_grace"] = "锦囊牌<br /><b>时机</b>：出牌阶段<br /><b>目标</b>：所有角色<br /><b>效果</b>：亮出牌堆顶等于目标角色数的牌，每名目标角色获得其中一张牌，结算结束后将其余的牌置入弃牌堆。",
  ["amazing_grace_skill"] = "五谷选牌",
  ["Please choose cards"] = "请选择一张卡牌",
  ["#amazing_grace_skill"] = "亮出牌堆顶等于所有角色数的牌，每名角色获得其中一张牌",

  ["lightning"] = "闪电",
  [":lightning"] = "延时锦囊牌<br /><b>时机</b>：出牌阶段<br /><b>目标</b>：你<br /><b>效果</b>：将此牌置于目标角色判定区内。其判定阶段进行判定：若结果为♠2-9，其受到3点雷电伤害并将【闪电】置入弃牌堆，否则将【闪电】移动至其下家判定区内。",
  ["#lightning_skill"] = "将此牌置于你的判定区内。目标角色判定阶段判定：<br />若结果为♠2-9，其受到3点雷电伤害并将【闪电】置入弃牌堆，否则将【闪电】移动至其下家判定区内",

  ["indulgence"] = "乐不思蜀",
  [":indulgence"] = "延时锦囊牌<br /><b>时机</b>：出牌阶段<br /><b>目标</b>：一名其他角色<br /><b>效果</b>：将此牌置于目标角色判定区内。其判定阶段进行判定：若结果不为<font color='#CC3131'>♥</font>，其跳过出牌阶段。然后将【乐不思蜀】置入弃牌堆。",
  ["#indulgence_skill"] = "选择一名其他角色，将此牌置于其判定区内。其判定阶段判定：<br />若结果不为<font color='#CC3131'>♥</font>，其跳过出牌阶段",

  ["crossbow"] = "诸葛连弩",
  [":crossbow"] = "装备牌·武器<br /><b>攻击范围</b>：１<br /><b>武器技能</b>：锁定技，你于出牌阶段内使用【杀】无次数限制。",
  ["#crossbow_skill"] = "诸葛连弩",

  ["qinggang_sword"] = "青釭剑",
  [":qinggang_sword"] = "装备牌·武器<br /><b>攻击范围</b>：２<br /><b>武器技能</b>：锁定技，你的【杀】无视目标角色的防具。",
  ["#qinggang_sword_skill"] = "青釭剑",

  ["ice_sword"] = "寒冰剑",
  [":ice_sword"] = "装备牌·武器<br /><b>攻击范围</b>：２<br /><b>武器技能</b>：当你使用【杀】对目标角色造成伤害时，若该角色有牌，你可以防止此伤害，然后依次弃置其两张牌。",
  ["#ice_sword_skill"] = "寒冰剑",

  ["double_swords"] = "雌雄双股剑",
  [":double_swords"] = "装备牌·武器<br /><b>攻击范围</b>：２<br /><b>武器技能</b>：当你指定异性角色为【杀】的目标后，你可以令其选择一项：弃置一张手牌，或令你摸一张牌。",
  ["#double_swords_skill"] = "雌雄双股剑",
  ["#double_swords-invoke"] = "雌雄双股剑：你需弃置一张手牌，否则 %src 摸一张牌",

  ["blade"] = "青龙偃月刀",
  [":blade"] = "装备牌·武器<br /><b>攻击范围</b>：３<br /><b>武器技能</b>：当你使用的【杀】被【闪】抵消后，你可以对该角色再使用一张【杀】（无距离限制且不能选择额外目标）。",
  ["#blade_skill"] = "青龙偃月刀",
  ["#blade_slash"] = "青龙偃月刀：你可以对 %src 再使用一张【杀】",

  ["spear"] = "丈八蛇矛",
  [":spear"] = "装备牌·武器<br /><b>攻击范围</b>：３<br /><b>武器技能</b>：你可以将两张手牌当【杀】使用或打出。",
  ["spear_skill"] = "丈八矛",
  [":spear_skill"] = "你可以将两张手牌当【杀】使用或打出。",
  ["#spear_skill"] = "你可以将两张手牌当【杀】使用或打出",

  ["axe"] = "贯石斧",
  [":axe"] = "装备牌·武器<br /><b>攻击范围</b>：３<br /><b>武器技能</b>：当你使用的【杀】被【闪】抵消后，你可以弃置两张牌，则此【杀】继续造成伤害。",
  ["#axe_skill"] = "贯石斧",
  ["#axe-invoke"] = "贯石斧：你可以弃置两张牌，令你对 %dest 使用的【杀】依然生效",

  ["halberd"] = "方天画戟",
  [":halberd"] = "装备牌·武器<br /><b>攻击范围</b>：４<br /><b>武器技能</b>：锁定技，你使用最后的手牌【杀】可以额外选择至多两名目标。",
  ["#halberd_skill"] = "方天画戟",

  ["kylin_bow"] = "麒麟弓",
  [":kylin_bow"] = "装备牌·武器<br /><b>攻击范围</b>：５<br /><b>武器技能</b>：当你使用【杀】对目标角色造成伤害时，你可以弃置其装备区里的一张坐骑牌。",
  ["#kylin_bow_skill"] = "麒麟弓",

  ["eight_diagram"] = "八卦阵",
  [":eight_diagram"] = "装备牌·防具<br /><b>防具技能</b>：当你需要使用或打出一张【闪】时，你可以进行判定：若结果为红色，视为你使用或打出了一张【闪】。",
  ["#eight_diagram_skill"] = "八卦阵",

  ["nioh_shield"] = "仁王盾",
  [":nioh_shield"] = "装备牌·防具<br /><b>防具技能</b>：锁定技，黑色【杀】对你无效。",
  ["#nioh_shield_skill"] = "仁王盾",

  ["dilu"] = "的卢",
  [":dilu"] = "装备牌·坐骑<br /><b>坐骑技能</b>：其他角色与你的距离+1。",

  ["jueying"] = "绝影",
  [":jueying"] = "装备牌·坐骑<br /><b>坐骑技能</b>：其他角色与你的距离+1。",

  ["zhuahuangfeidian"] = "爪黄飞电",
  [":zhuahuangfeidian"] = "装备牌·坐骑<br /><b>坐骑技能</b>：其他角色与你的距离+1。",

  ["chitu"] = "赤兔",
  [":chitu"] = "装备牌·坐骑<br /><b>坐骑技能</b>：你与其他角色的距离-1。",

  ["dayuan"] = "大宛",
  [":dayuan"] = "装备牌·坐骑<br /><b>坐骑技能</b>：你与其他角色的距离-1。",

  ["zixing"] = "紫骍",
  [":zixing"] = "装备牌·坐骑<br /><b>坐骑技能</b>：你与其他角色的距离-1。",

  ["#default_equip_skill"] = "装备%arg2【%arg】",
}
