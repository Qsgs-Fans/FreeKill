-- SPDX-License-Identifier: GPL-3.0-or-later

Fk:loadTranslationTable{
  -- Lobby
  ["Room List"] = "房间列表 (共%1个房间)",
  ["Enter"] = "进入",
  ["Observe"] = "旁观",

  ["Edit Profile"] = "编辑个人信息",
  ["Username"] = "用户名",
  ["Avatar"] = "头像",
  ["Old Password"] = "旧密码",
  ["New Password"] = "新密码",
  ["Update Avatar"] = "更新头像",
  ["Update Password"] = "更新密码",
  ["Lobby BG"] = "大厅壁纸",
  ["Room BG"] = "房间背景",
  ["Game BGM"] = "游戏BGM",
  ["Poster Girl"] = "看板娘",
  ["BGM Volume"] = "BGM音量",
  ["Effect Volume"] = "音效音量",
  ["Userinfo Settings"] = "个人信息",
  ["BG Settings"] = "游戏背景",
  ["Audio Settings"] = "音频",
  ["Disable message audio"] = "禁用聊天语音",
  ["Hide unselectable cards"] = "下移不可选卡牌",
  ["Ban General Settings"] = "禁将",
  ["Search"] = "搜索",
  ["Back"] = "返回",

  ["Refresh Room List"] = "刷新房间列表",

  ["Disable Extension"] = "禁用Lua拓展 (重启后生效)",
  ["Create Room"] = "创建房间",
  ["Room Name"] = "房间名字",
  ["$RoomName"] = "%1的房间",
  ["Player num"] = "玩家数目",
  ["Select generals num"] = "选将数目",
  ["No enough generals"] = "可用武将不足！",
  ["Operation timeout"] = "操作时长(秒)",
  ["Luck Card Times"] = "手气卡次数",
  ["Has Password"] = "（有密码）",
  ["Room Password"] = "房间密码",
  ["Please input room's password"] = "请输入房间的密码",
  ["Add Robot"] = "添加机器人",
  ["Start Game"] = "开始游戏",
  ["Ready"] = "准备",
  ["Cancel Ready"] = "取消准备",
  ["Game Mode"] = "游戏模式",
  ["Enable free assign"] = "自由选将",
  ["Enable deputy general"] = "启用副将机制",
  ["General Settings"] = "通常设置",
  ["Package Settings"] = "拓展包设置",
  ["General Packages"] = "武将拓展包",
  ["Card Packages"] = "卡牌拓展包",
  ["Select All"] = "全选",
  ["Choose one handcard"] = "选卡",
  ["Revert Selection"] = "反选",
  ["Handcard selector"] = "手牌选择器，只可选一张，代为点击这张手牌",

  ["Give Flower"] = "送花",
  ["Give Egg"] = "砸蛋",
  ["Give Wine"] = "酒杯",
  ["Give Shoe"] = "拖鞋",
  ["Block Chatter"] = "屏蔽发言",
  ["Unblock Chatter"] = "解除屏蔽",
  ["Kick From Room"] = "踢出房间",
  ["Newbie"] = "新手保护ing",
  ["Win=%1 Run=%2 Total=%3"] = "胜率%1% 逃率%2% 总场次%3",
  ["Win=%1\nRun=%2\nTotal=%3"] = "胜率: %1%\n逃率: %2%\n总场次: %3",

  ["Ban List"] = "禁将方案",
  ["List"] = "方案",
  ["New"] = "新建",
  ["Clear"] = "清空",
  ["Help_Ban_List"] = "导出键会将这个方案的内容复制到剪贴板中；" ..
  "导入键会自动读取剪贴板，若可以导入则导入，不能导入则报错。",
  ["Export"] = "导出",
  ["Export Success"] = "禁将方案已经复制到剪贴板。",
  ["Import"] = "导入",
  ["Not Legal"] = "导入失败：不是合法的JSON字符串。",
  ["Not JSON"] = "导入失败：数据格式不对。",
  ["Import Success"] = "从剪贴板导入禁将方案成功。",

  ["$OnlineInfo"] = "大厅人数：%1，总在线人数：%2",

  ["Generals Overview"] = "武将一览",
  ["Cards Overview"] = "卡牌一览",
  ["Special card skills:"] = "<b>卡牌的特殊用法:</b>",
  ["Every suit & number:"] = "<b>所有的花色和点数:</b>",
  ["Scenarios Overview"] = "玩法一览",
  ["Replay"] = "录像",
  ["Replay Manager"] = "来欣赏潇洒的录像吧！",
  ["Game Win"] = "胜利",
  ["Game Lose"] = "失败",
  ["Play the Replay"] = "重放",
  ["Delete Replay"] = "删除",
  ["About"] = "关于",
  ["about_freekill_description"] = [[
# 关于新月杀

以便于DIY为首要目的的开源三国杀游戏。

项目链接： https://github.com/Notify-ctrl/FreeKill

---

作者： Notify Ho-spair

开发者： RalphR Nyutanislavsky xxyheaven 妖梦厨

贡献者： 假象 deepskybird 板蓝根

鸣谢： Mogara

  ]],
  ["about_qt_description"] = [[
# 关于Qt

Qt是一个C++图形界面应用程序开发框架，拥有强大的跨平台能力以及易于使用的API。

本程序使用Qt 6.4，主要利用QtQuick开发UI，同时也使用Qt的网络库开发服务端程序。

官网： https://www.qt.io
  ]],
  ["about_lua_description"] = [[
# 关于Lua

Lua是一种小巧、灵活、高效的脚本语言，广泛用于游戏开发中。

本程序使用Lua 5.4，利用其完全实现了整个游戏逻辑。

官网： https://www.lua.org
  ]],
  ["about_ossl_description"] = [[
# 关于OpenSSL

OpenSSL是一个开源包，用来提供安全通信与各种加密支持。

本程序目前用到了crypto库，以获得RSA加密算法支持。

官网： https://www.openssl.org
  ]],
  ["about_gplv3_description"] = [[
# 关于GPLv3

GNU通用公共许可协议（简称GPL）是一个广泛使用的自由软件许可证条款，它确保广大用户自由地使用、学习、共享或修改软件。

由于Qt是按照GPLv3协议开源的库，与此同时本程序用到的readline库也属于GPLv3库，再加上QSanguosha也是以GPLv3协议开源的软件（从中借鉴了不少代码和思路），因此这个项目也使用GPLv3协议开源。

官网： https://gplv3.fsf.org
  ]],
  ["about_sqlite_description"] = [[
# 关于SQLite

SQLite是一个轻量级的数据库，具有占用资源低、运行效率快、嵌入性好等优点。

FreeKill使用sqlite3在服务端保存用户的各种信息。

官网： https://www.sqlite.org
  ]],
  ["about_git2_description"] = [[
# 关于Libgit2

Libgit2是一个轻量级的、跨平台的、纯C实现的库，支持Git的大部分核心操作，并且支持几乎任何能与C语言交互的编程语言。

FreeKill使用的是libgit2的C API，与此同时使用Git完成拓展包的下载、更新、管理等等功能。

官网： https://libgit2.org
  ]],

  ["Exit Lobby"] = "退出大厅",

  ["SkipNullification"] = "本轮忽略",
  ["OK"] = "确定",
  ["Cancel"] = "取消",
  ["End"] = "结束",
  -- ["Quit"] = "退出",
  ["BanGeneral"] = "禁将",
  ["ResumeGeneral"] = "解禁",
  ["Companions"] = "珠联璧合",
  ["Death audio"] = "阵亡",

  ["$WelcomeToLobby"] = "欢迎进入新月杀游戏大厅！",
  ["LuckCardNum"] = "手气卡次数：",
  ["ResponseTime"] = "出手时间：",
  ["GeneralBoxNum"] = "选将框数：",
  ["IncludeFreeAssign"] = "<font color=\"red\">可自由点将</font>",
  ["IncludeDeputy"] = "<font color=\"red\">启用副将机制</font>",

  -- Room
  ["$EnterRoom"] = "成功加入房间。",
  ["#currentRoundNum"] = "第 %1 轮",
  ["$Choice"] = "%1：请选择",
  ["$ChooseGeneral"] = "请选择 %1 名武将",
  ["Same General Convert"] = "替换武将",
  ["Fight"] = "出战",
  ["Show General Detail"] = "查看技能",

  ["#PlayCard"] = "出牌阶段，请使用一张牌",
  ["#AskForGeneral"] = "请选择 1 名武将",
  ["#AskForSkillInvoke"] = "你想发动技能“%1”吗？",
  ["#AskForLuckCard"] = "你想使用手气卡吗？还可以使用 %1 次，剩余手气卡∞张",
  ["AskForLuckCard"] = "手气卡",
  ["#AskForChoice"] = "%1：请选择",
  ["#choose-trigger"] = "请选择一项技能发动",
  ["trigger"] = "选择技能",
  ["Please arrange cards"] = "请拖拽移动卡牌",
  ["Please click to move card"] = "请点击移动卡牌",

  [" thinking..."] = " 思考中...",
  ["AskForGeneral"] = "选择武将",
  ["AskForGuanxing"] = "观星",
  ["AskForExchange"] = "换牌",
  ["AskForChoice"] = "选择",
  ["AskForKingdom"] = "选择势力",
  ["AskForPindian"] = "拼点",
  ["AskForMoveCardInBoard"] = "移动卡牌",
  ["PlayCard"] = "出牌",

  ["AskForCardChosen"] = "选牌",
  ["AskForCardsChosen"] = "选牌",
  ["#AskForChooseCard"] = "%1：请选择其一张卡牌",
  ["#AskForChooseCards"] = "%1：请选择其%2至%3张卡牌",
  ["$ChooseCard"] = "请选择一张卡牌",
  ["$ChooseCards"] = "请选择%1至%2张卡牌",
  ["$Hand"] = "手牌区",
  ["$Equip"] = "装备区",
  ["$Judge"] = "判定区",
  ['$Selected'] = "已选择",
  ["#AskForUseActiveSkill"] = "请使用技能 %1",
  ["#AskForUseCard"] = "请使用卡牌 %1",
  ["#AskForResponseCard"] = "请打出卡牌 %1",
  ["#AskForNullification"] = "是否为目标为 %dest 的 %arg 使用无懈可击？",
  ["#AskForNullificationWithoutTo"] = "是否对 %src 使用的 %arg 使用无懈可击？",
  ["#AskForPeaches"] = "%src 生命危急，需要 %arg 个桃",
  ["#AskForPeachesSelf"] = "你生命危急，需要 %arg 个桃或酒",

  ["#AskForDiscard"] = "请弃置 %arg 张牌，最少 %arg2 张",
  ["#AskForCard"] = "请选择 %arg 张牌，最少 %arg2 张",
  ["#askForPindian"] = "%arg：请选择一张手牌作为拼点牌",
  ["#StartPindianReason"] = "%from 由于 %arg 而发起拼点",
  ["#ShowPindianCard"] = "%from 的拼点牌是 %card",
  ["#ShowPindianResult"] = "%from 在 %from 和 %to 之间的拼点中 %arg",
  ["pindianwin"] = "赢",
  ["pindiannotwin"] = "没赢",

  ["#ChooseInitialKingdom"] = "请选择初始势力（不可变更）",

  ["#RevealGeneral"] = "%from 亮出 %arg %arg2",
  ["mainGeneral"] = "主将",
  ["deputyGeneral"] = "副将",
  ["seat#1"] = "一号位",
  ["seat#2"] = "二号位",
  ["seat#3"] = "三号位",
  ["seat#4"] = "四号位",
  ["seat#5"] = "五号位",
  ["seat#6"] = "六号位",
  ["seat#7"] = "七号位",
  ["seat#8"] = "八号位",
  ["seat#9"] = "九号位",
  ["seat#10"] = "十号位",
  ["seat#11"] = "十一号位",
  ["seat#12"] = "十二号位",
  ["@ControledBy"] = "控制者",

  ["Menu"] = "菜单",
  ["Surrender"] = "投降",
  ["Surrender is disabled in this mode"] = "投降在该模式不可用",
  ["Quit"] = "退出",
  ["Are you sure to quit?"] = "是否确认退出对局（若对局开始则将计入逃跑次数）？",

  ["Trust"] = "托管",
  ["Sort Cards"] = "牌序",
  ["Chat"] = "聊天",
  ["Log"] = "战报",
  ["Trusting ..."] = "托管中 ...",
  ["Observing ..."] = "旁观中 ...",

  ["$GameOver"] = "游戏结束",
  ["$Winner"] = "%1 获胜",
  ["$NoWinner"] = "平局！",
  ["Back To Room"] = "回到房间",
  ["Back To Lobby"] = "返回大厅",
  ["Save Replay"] = "保存录像",

  ["Speed Resume"] = "匀速",
  ["Speed Up"] = "加速",
  ["Speed Down"] = "减速",
  ["Pause"] = "暂停",
  ["Resume"] = "继续",

  ["Bulletin Info"] = [==[
  ## v0.3.10

  优化锁住卡牌的游玩体验，增加了新人引导。

  ]==],
}

-- Game concepts
Fk:loadTranslationTable{
  ["lord"] = "主公",
  ["loyalist"] = "忠臣",
  ["rebel"] = "反贼",
  ["renegade"] = "内奸",
  ["lord+loyalist"] = "主忠",

  ["normal_damage"] = "无属性",
  ["fire_damage"] = "火属性",
  ["thunder_damage"] = "雷属性",
  ["ice_damage"] = "冰属性",
  ["hp_lost"] = "体力流失",

  ["phase_start"] = "准备阶段",
  ["phase_judge"] = "判定阶段",
  ["phase_draw"] = "摸牌阶段",
  ["phase_play"] = "出牌阶段",
  ["phase_discard"] = "弃牌阶段",
  ["phase_finish"] = "结束阶段",

  ["chained"] = "横置",
  ["un-chained"] = "重置",
  ["reset-general"] = "复原",

  ["yang"] = "阳",
  ["yin"] = "阴",
  ["quest_succeed"] = "成功",
  ["quest_failed"] = "失败",

  ["card"] = "牌",
  ["hand_card"] = "手牌",
  ["pile_draw"] = "牌堆",
  ["pile_discard"] = "弃牌堆",
  ["processing_area"] = "处理区",
  ["Pile"] = "牌堆",
  ["Top"] = "牌堆顶",
  ["Bottom"] = "牌堆底",
  ["Shuffle"] = "洗牌",

  ["general_card"] = "武将牌",
  ["General"] = "武将",
  ["noGeneral"] = "无武将",
  ["Hp"] = "体力",
  ["Damage"] = "伤害",
  ["Lost"] = "失去",
  ["Distance"] = "距离",
  ["Judge"] = "判定",
  ["Retrial"] = "改判",

  ["_sealed"] = "废除",
  ["weapon_sealed"] = "武器栏废除",
  ["armor_sealed"] = "防具栏废除",
  ["treasure_sealed"] = "宝物栏废除",

  ["WeaponSlot"] = "武器栏",
  ["ArmorSlot"] = "防具栏",
  ["OffensiveRideSlot"] = "进攻坐骑栏",
  ["DefensiveRideSlot"] = "防御坐骑栏",
  ["TreasureSlot"] = "宝物栏",
  ["JudgeSlot"] = "判定区",
}

-- related to sendLog
Fk:loadTranslationTable{
  -- game processing
  ["$AppendSeparator"] = '<font color="grey">------------------------------</font>',
  ["$GameStart"] = "== 游戏开始 ==",
  ["$GameEnd"] = "== 游戏结束 ==",

  -- get/lose skill
  ["#AcquireSkill"] = "%from 获得了技能 “%arg”",
	["#LoseSkill"] = "%from 失去了技能 “%arg”",

  -- moveCards (they are sent by notifyMoveCards)
  ["$PutCard"] = "%from 的 %arg 张牌被置于牌堆",
  ["$PutKnownCard"] = "%from 的牌 %card 被置于牌堆",
  ["$RemoveCardFromGame"] = "%arg2 张牌被作为 %arg 移出游戏",
  ["$AddToPile"] = "%card 被作为 %arg 移出游戏",
  ["$GetCardsFromPile"] = "%from 从 %arg 中获得了 %arg2 张牌 %card",
  ["$DrawCards"] = "%from 摸了 %arg 张牌 %card",
  ["$PreyCardsFromPile"] = "%from 获得了 %arg 张牌 %card",
  ["$GotCardBack"] = "%from 收回了 %arg 张牌 %card",
  ["$RecycleCard"] = "%from 从弃牌堆回收了 %arg 张牌 %card",
  ["$MoveCards"] = "%to 从 %from 处获得了 %arg 张牌 %card",
  ["$LightningMove"] = "%card 从 %from 转移到了 %to",
  ["$PasteCard"] = "%from 给 %to 贴了张 %card",
  ["$DiscardCards"] = "%from 弃置了 %arg 张牌 %card",
  ["$InstallEquip"] = "%from 装备了 %card",
  ["$UninstallEquip"] = "%from 卸载了 %card",

  ["#ShowCard"] = "%from 展示了牌 %card",
  ["#Recast"] = "%from 重铸了 %card",
  ["#RecastBySkill"] = "%from 发动了 “%arg” 重铸了 %card",

  -- phase
  ["#PhaseSkipped"] = "%from 跳过了 %arg",
  ["#GainAnExtraTurn"] = "%from 开始进行一个额外的回合",
  ["#GainAnExtraPhase"] = "%from 开始进行一个额外的 %arg",

  -- useCard
  ["#UseCard"] = "%from 使用了牌 %card",
  ["#UseCardToTargets"] = "%from 使用了牌 %card，目标是 %to",
  ["#CardUseCollaborator"] = "%from 在此次 %arg 中的子目标是 %to",
  ["#UseCardToCard"] = "%from 使用了牌 %card，目标是 %arg",
  ["#ResponsePlayCard"] = "%from 打出了牌 %card",

  ["#UseVCard"] = "%from 将 %card 当 %arg 使用",
  ["#UseVCardToTargets"] = "%from 将 %card 当 %arg 使用，目标是 %to",
  ["#UseVCardToCard"] = "%from 将 %card 当 %arg2 使用，目标是 %arg",
  ["#ResponsePlayVCard"] = "%from 将 %card 当 %arg 打出",
  ["#UseV0Card"] = "%from 使用了 %arg",
  ["#UseV0CardToTargets"] = "%from 使用了 %arg，目标是 %to",
  ["#UseV0CardToCard"] = "%from 使用了 %arg2，目标是 %arg",
  ["#ResponsePlayV0Card"] = "%from 打出了 %arg",

  ["#FilterCard"] = "由于 %arg 的效果，与 %from 相关的 %arg2 被视为了 %arg3",

  -- skill
  ["#InvokeSkill"] = "%from 发动了 “%arg”",

  -- judge
  ["#StartJudgeReason"] = "%from 开始了 %arg 的判定",
  ["#InitialJudge"] = "%from 的判定牌为 %card",
  ["#ChangedJudge"] = "%from 发动“%arg”把 %to 的判定牌改为 %card",
  ["#JudgeResult"] = "%from 的判定结果为 %card",

  -- turnOver
  ["#TurnOver"] = "%from 将武将牌翻面，现在是 %arg",
	["face_up"] = "正面朝上",
	["face_down"] = "背面朝上",

  -- damage, heal and lose HP
  ["#Damage"] = "%to 对 %from 造成了 %arg 点 %arg2 伤害",
  ["#DamageWithNoFrom"] = "%from 受到了 %arg 点 %arg2 伤害",
  ["#LoseHP"] = "%from 失去了 %arg 点体力",
  ["#HealHP"] = "%from 回复了 %arg 点体力",
  ["#ShowHPAndMaxHP"] = "%from 现在的体力值为 %arg，体力上限为 %arg2",
  ["#LoseMaxHP"] = "%from 减了 %arg 点体力上限",
  ["#HealMaxHP"] = "%from 加了 %arg 点体力上限",

  -- dying and death
  ["#EnterDying"] = "%from 进入了濒死阶段",
  ["#KillPlayer"] = "%from [%arg] 阵亡，凶手是 %to",
  ["#KillPlayerWithNoKiller"] = "%from [%arg] 阵亡，无伤害来源",
  ["#Revive"] = "%from 竟然复活了",

  -- change hero
  ["#ChangeHero"] = "%from 的 %arg3 %arg 变更为 %arg2",

  -- misc
  ["#GuanxingResult"] = "%from 的观星结果为 %arg 上 %arg2 下",
  ["#ChainStateChange"] = "%from %arg 了武将牌",
  ["#ChainDamage"] = "%from 处于连环状态，将受到传导的伤害",
  ["#ChangeKingdom"] = "%from 的国籍从 %arg 变成了 %arg2",
}

-- card footnote
Fk:loadTranslationTable{
  ["$$DiscardCards"] = "%from弃置",
  ["$$PutCard"] = "%from置于",

  ["##UseCard"] = "%from使用",
  ["##UseCardTo"] = "%from对%to",
  ["##ResponsePlayCard"] = "%from打出",
  ["##ShowCard"] = "%from展示",
  ["##JudgeCard"] = "%arg判定",
}
