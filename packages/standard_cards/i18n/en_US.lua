-- SPDX-License-Identifier: GPL-3.0-or-later

Fk:loadTranslationTable({
  ["standard_cards"] = "Standard",

  ["unknown_card"] = '<font color="#B5BA00"><b>Unknown card</b></font>',
  ["log_spade"] = '♠',
  ["log_heart"] = '<font color="#CC3131">♥</font>',
  ["log_club"] = '♣',
  ["log_diamond"] = '<font color="#CC3131">♦</font>',
  ["log_nosuit"] = "X",
  ["log_unknown"] = "?",
  -- ["spade"] = "Spade",
  -- ["heart"] = "Heart",
  -- ["club"] = "Club",
  -- ["diamond"] = "Diamond",
  ["nosuit"] = "No suit",
  ["black"] = 'Black',
  ["red"] = '<font color="#CC3131">Red</font>',
  ["nocolor"] = '<font color="grey">NoColor</font>',
  -- ["suit"] = "花色",
  -- ["color"] = "颜色",
  -- ["number"] = "点数",

  ["basic_char"] = "Ba.",
  ["trick_char"] = "Tr.",
  ["equip_char"] = "Eq.",

  -- ["basic"] = "基本牌",
  -- ["trick"] = " (trick card)",
  -- ["equip"] = "装备牌",
  -- ["weapon"] = "武器牌",
  -- ["armor"] = "防具牌",
  ["defensive_horse"] = "+1 horse",
  ["defensive_ride"] = "+1 horse",
  ["offensive_horse"] = "-1 horse",
  ["offensive_ride"] = "-1 horse",
  ["equip_horse"] = "horse",
  -- ["treasure"] = "宝物牌",
  ["delayed_trick"] = "delayed trick",
  ["damage_card-"] = "DMG card",
  ["multiple_targets-"] = "multiple targets",

  ["type_weapon"] = "weapon",
  ["type_armor"] = "armor",
  ["type_defensive_horse"] = "+1 horse",
  ["type_offensive_horse"] = "-1 horse",
  ["type_horse"] = "horse",

  ["method_use"] = "use",
  ["method_response_play"] = "play",
  ["method_response"] = "respond",
  ["method_draw"] = "draw",
  ["method_discard"] = "discard",

  ["prohibit"] = " prohibit ",

  ["slash"] = "Slash",
  [":slash"] = "Slash (basic card)<br /><b>Phase</b>: Action phase<br /><b>Target</b>: Another player within your ATK range<br /><b>Effect</b>: Deal 1 DMG to the targets.<br/><b>Note</b>: You can only use 1 Slash per action phase.",
  ["#slash-jink"] = "%src used Slash to you, please use a Dodge",
  ["#slash-jink-multi"] = "%src used Slash to you, please use a Dodge( %arg th, %arg2 total )",
  ["#slash_skill"] = "Choose 1 player within your ATK range, deal 1 DMG to him",
  ["#slash_skill_multi"] = "Choose up to %arg players within your ATK range. Deal 1 DMG to them",

  ["jink"] = "Dodge",
  [":jink"] = "Dodge (basic card)<br /><b>Phase</b>: When Slash is about to effect on you<br /><b>Target</b>: This Slash<br /><b>Effect</b>: Counter the target Slash.",

  ["peach"] = "Peach",
  [":peach"] = "Peach (basic card)<br /><b>Phase</b>: 1. Action phase 2. When a player is dying<br /><b>Target</b>: Wounded yourself/the player who is dying<br /><b>Effect</b>: The target heals 1 HP.",
  ["#peach_skill"] = "You heal 1 HP",

  ["dismantlement"] = "Dismantlement",
  [":dismantlement"] = "Dismantlement (trick card)<br /><b>Phase</b>: Action phase<br /><b>Target</b>: Another player with cards in any area<br /><b>Effect</b>: Discard 1 card in one of the areas of the target player.",
  ["dismantlement_skill"] = "Dismantlement",
  ["#dismantlement_skill"] = "Choose another player with cards in any area. Discard 1 card in one of his areas",

  ["snatch"] = "Snatch",
  [":snatch"] = "Snatch (trick card)<br /><b>Phase</b>: Action phase<br /><b>Target</b>: Another player at distance 1 with cards in any area<br /><b>Effect</b>: Take 1 card in one of the areas of the target player.",
  ["snatch_skill"] = "Snatch",
  ["#snatch_skill"] = "Choose another player at distance 1 with cards in any area. Take 1 card in one of his areas",

  ["duel"] = "Duel",
  [":duel"] = "Duel (trick card)<br /><b>Phase</b>: Action phase<br /><b>Target</b>: Another player<br /><b>Effect</b>: In turns (starting with the target player), both of you play Slash successively. The first player who doesn't play Slash suffers 1 DMG from the other player.",
  ["#duel_skill"] = "Choose another player. In turns (starting with the target player), both of you play Slash successively.<br />The first player who doesn't play Slash suffers 1 DMG from the other player",

  ["collateral"] = "Collateral",
  [":collateral"] = "Collateral (trick card)<br /><b>Phase</b>: Action phase<br /><b>Target</b>: Another player with an equipped weapon (Player A)<br /><b>Sub-target</b>: A player within Player A's ATK range (Player B)<br /><b>Effect</b>: Unless A uses Slash to B, he gives you his equipped weapon.",
  ["#collateral-slash"] = "Collateral: You shall use Slash to %dest , or give your weapon to %src",
  ["#collateral_skill"] = "Choose another player with an equipped weapon (Player A),<br />then choose another player within Player A's ATK range (Player B).<br />Unless A uses Slash to B, he gives you his equipped weapon",

  ["ex_nihilo"] = "Ex Nihilo",
  [":ex_nihilo"] = "Ex Nihilo (trick card)<br /><b>Phase</b>: Action phase<br /><b>Target</b>: Yourself<br /><b>Effect</b>: The target draws 2 cards.",
  ["#ex_nihilo_skill"] = "You draw 2 cards",

  ["nullification"] = "Nullification",
  [":nullification"] = "Nullification (trick card)<br /><b>Phase</b>: When a trick card is about to take effect (including Nullification itself)<br /><b>Target</b>: This trick card<br /><b>Effect</b>: Counter the target trick card.",

  ["savage_assault"] = "Savage Assault",
  [":savage_assault"] = "Savage Assault (trick card)<br /><b>Phase</b>: Action phase<br /><b>Target</b>: All other players<br /><b>Effect</b>: Each target player needs to play Slash, otherwise they suffer 1 DMG from you.",
  ["#savage_assault_skill"] = "Each other players needs to play Slash, otherwise they suffer 1 DMG from you",

  ["archery_attack"] = "Archery Attack",
  [":archery_attack"] = "Archery Attack (trick card)<br /><b>Phase</b>: Action phase<br /><b>Target</b>: All other players<br /><b>Effect</b>: Each target player needs to play Dodge, otherwise they suffer 1 DMG from you.",
  ["#archery_attack_skill"] = "Each other players needs to play Dodge, otherwise they suffer 1 DMG from you",

  ["god_salvation"] = "God Salvation",
  [":god_salvation"] = "God Salvation (trick card)<br /><b>Phase</b>: Action phase<br /><b>Target</b>: All players<br /><b>Effect</b>: Each target player heals 1 HP.",
  ["#god_salvation_skill"] = "Each players heals 1 HP",

  ["amazing_grace"] = "Amazing Grace",
  [":amazing_grace"] = "Amazing Grace (trick card)<br /><b>Phase</b>: Action phase<br /><b>Target</b>: All players<br /><b>Effect</b>: Reveal as many cards from the draw pile as target players; then, each target player takes 1 of those cards.",
  ["amazing_grace_skill"] = "AG",
  ["Please choose cards"] = "Please choose a card",
  ["#amazing_grace_skill"] = "Reveal as many cards from the draw pile as all players;<br />then, each player takes 1 of those cards",

  ["lightning"] = "Lightning",
  [":lightning"] = "Lightning (delayed trick card)<br /><b>Phase</b>: Action phase<br /><b>Target</b>: Yourself<br /><b>Effect</b>: Place this card in target's judgement area. He performs a judgement in his judge phase: If the judgement result is 2-9♠, he suffers 3 Thunder DMG, otherwise move Lightning to his next player's judgement area.",
  ["#lightning_skill"] = "Place this card in your judgement area. Target player performs a judgement in his judge phase:<br />If the judgement result is 2-9♠, he suffers 3 Thunder DMG, otherwise move Lightning to his next player's judgement area",

  ["indulgence"] = "Indulgence",
  [":indulgence"] = "Indulgence (delayed trick card)<br /><b>Phase</b>: Action phase<br /><b>Target</b>: Another player<br /><b>Effect</b>: Place this card in target's judgement area. He performs a judgement in his judge phase: if result is not <font color='#CC3131'>♥</font>, he skips his action phase.",
  ["#indulgence_skill"] = "Place this card in another player's judgement area. He performs a judgement in his judge phase:<br />If result is not <font color='#CC3131'>♥</font>, he skips his action phase",

  ["crossbow"] = "Crossbow",
  [":crossbow"] = "Crossbow (equip card, weapon)<br /><b>ATK range</b>: 1<br /><b>Weapon skill</b>: You can use any amount of Slash in your action phase.",
  ["#crossbow_skill"] = "Crossbow",

  ["qinggang_sword"] = "Qinggang Sword",
  [":qinggang_sword"] = "Qinggang Sword (equip card, weapon)<br /><b>ATK range</b>: 2<br /><b>Weapon skill</b>: Your Slash ignores the target's armor.",
  ["#qinggang_sword_skill"] = "Qinggang Sword",

  ["ice_sword"] = "Ice Sword",
  [":ice_sword"] = "Ice Sword (equip card, weapon)<br /><b>ATK range</b>: 2<br /><b>Weapon skill</b>: When your used Slash is about to cause DMG to a player who has cards, you can prevent this DMG and discard him 2 cards successively.",
  ["#ice_sword_skill"] = "Ice Sword",

  ["double_swords"] = "Double Sword",
  [":double_swords"] = "Double Sword (equip card, weapon)<br /><b>ATK range</b>: 2<br /><b>Weapon skill</b>: After your used Slash targets a character of the opposite gender, you can make him choose: 1. discard 1 hand card; 2. you draw 1 card.",
  ["#double_swords_skill"] = "Double Sword",
  ["#double_swords-invoke"] = "Double Sword: You shall discard 1 handcard，or %src draws 1",

  ["blade"] = "Blade",
  [":blade"] = "Blade (equip card, weapon)<br /><b>ATK range</b>: 3<br /><b>Weapon skill</b>: When your used Slash is countered by Dodge, you can use another Slash immediately on the same target.",
  ["#blade_skill"] = "Blade",
  ["#blade_slash"] = "Blade: You can use another Slash to %src",

  ["spear"] = "Spear",
  [":spear"] = "Spear (equip card, weapon)<br /><b>ATK range</b>: 3<br /><b>Weapon skill</b>: You can use/play 2 hand cards as Slash.",
  ["spear_skill"] = "Spear",
  [":spear_skill"] = "You can use/play 2 hand cards as Slash.",
  ["#spear_skill"] = "You can use/play 2 hand cards as Slash",

  ["axe"] = "Axe",
  [":axe"] = "Axe (equip card, weapon)<br /><b>ATK range</b>: 3<br /><b>Weapon skill</b>: When your used Slash is countered by Dodge, you can discard 2 cards (except equipped Axe), then make this Slash still effective to the target.",
  ["#axe_skill"] = "Axe",
  ["#axe-invoke"] = "Axe: You may discard 2 cards to ensure your Slash effective to %dest",

  ["halberd"] = "Halberd",
  [":halberd"] = "Halberd (equip card, weapon)<br /><b>ATK range</b>: 4<br /><b>Weapon skill</b>: When you are about to use Slash which is your last hand card, you can target up to +2 extra targets.",
  ["#halberd_skill"] = "Halberd",

  ["kylin_bow"] = "Kylin Bow",
  [":kylin_bow"] = "Kylin Bow (equip card, weapon)<br /><b>ATK range</b>: 5<br /><b>Weapon skill</b>: When your used Slash is about to cause DMG, you can discard 1 of his equipped horse.",
  ["#kylin_bow_skill"] = "Kylin Bow",

  ["eight_diagram"] = "Eight Diagram",
  [":eight_diagram"] = "Eight Diagram (equip card, armor)<br /><b>Armor skill</b>: When you need to use/play Dodge: you can perform a judgement; if it's red, you are regarded as having used/played Dodge.",
  ["#eight_diagram_skill"] = "Eight Diagram",

  ["nioh_shield"] = "Nioh Shield",
  [":nioh_shield"] = "Nioh Shield (equip card, armor)<br /><b>Armor skill</b>: Black Slash has no effect on you.",
  ["#nioh_shield_skill"] = "Nioh Shield",

  ["dilu"] = "Di Lu",
  [":dilu"] = "Di Lu (equip card, horse)<br /><b>Horse skill</b>: The distance from other players to you is increased by +1.",

  ["jueying"] = "Jue Ying",
  [":jueying"] = "Jue Ying (equip card, horse)<br /><b>Horse skill</b>: The distance from other players to you is increased by +1.",

  ["zhuahuangfeidian"] = "Zhua Huang Fei Dian",
  [":zhuahuangfeidian"] = "Zhua Huang Fei Dian (equip card, horse)<br /><b>Horse skill</b>: The distance from other players to you is increased by +1.",

  ["chitu"] = "Chi Tu",
  [":chitu"] = "Chi Tu (equip card, horse)<br /><b>Horse skill</b>: The distance from you to other players is reduced by -1.",

  ["dayuan"] = "Da Yuan",
  [":dayuan"] = "Da Yuan (equip card, horse)<br /><b>Horse skill</b>: The distance from you to other players is reduced by -1.",

  ["zixing"] = "Zi Xing",
  [":zixing"] = "Zi Xing (equip card, horse)<br /><b>Horse skill</b>: The distance from you to other players is reduced by -1.",

  ["#default_equip_skill"] = "Equip %arg",
}, "en_US")
