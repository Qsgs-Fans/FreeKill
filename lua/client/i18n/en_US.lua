-- SPDX-License-Identifier: GPL-3.0-or-later

Fk:loadTranslationTable({
  -- Lobby
  ["Room List"] = "Room List (currently have %1 rooms)",
  -- ["Enter"] = "进入",
  -- ["Observe"] = "旁观",

  -- ["Edit Profile"] = "编辑个人信息",
  -- ["Username"] = "用户名",
  -- ["Avatar"] = "头像",
  -- ["Old Password"] = "旧密码",
  -- ["New Password"] = "新密码",
  -- ["Update Avatar"] = "更新头像",
  -- ["Update Password"] = "更新密码",
  -- ["Lobby BG"] = "大厅壁纸",
  -- ["Room BG"] = "房间背景",
  -- ["Game BGM"] = "游戏BGM",
  -- ["Poster Girl"] = "看板娘",
  -- ["BGM Volume"] = "BGM音量",
  -- ["Effect Volume"] = "音效音量",
  -- ["Userinfo Settings"] = "个人信息",
  -- ["BG Settings"] = "游戏背景",
  -- ["Audio Settings"] = "音频",
  -- ["Disable message audio"] = "禁用聊天语音",
  -- ["Hide unselectable cards"] = "下移不可选卡牌",
  ["Ban General Settings"] = "Ban character settings",
  -- ["Search"] = "搜索",
  -- ["Back"] = "返回",

  -- ["Refresh Room List"] = "刷新房间列表",

  ["Disable Extension"] = "Please ignore this checkbox",
  -- ["Create Room"] = "创建房间",
  -- ["Room Name"] = "房间名字",
  ["$RoomName"] = "%1's room",
  ["Player num"] = "Player count",
  ["Select generals num"] = "Character selection count",
  -- ["No enough generals"] = "可用武将不足！",
  ["Operation timeout"] = "Operation timeout (sec)",
  ["Luck Card Times"] = "Luck card count",
  ["Has Password"] = "(PW) ",
  -- ["Room Password"] = "房间密码",
  -- ["Please input room's password"] = "请输入房间的密码",
  ["Add Robot"] = "Add robot",
  ["Start Game"] = "Start game",
  -- ["Ready"] = "准备",
  ["Cancel Ready"] = "Cancel ready",
  ["Game Mode"] = "Game mode",
  -- ["Enable free assign"] = "自由选将",
  ["Enable deputy general"] = "Enable deputy character",
  -- ["General Settings"] = "通常设置",
  -- ["Package Settings"] = "拓展包设置",
  ["General Packages"] = "Character packages",
  ["Card Packages"] = "Card packages",
  -- ["Select All"] = "全选",
  ["Choose one handcard"] = "Sel. card",
  ["Revert Selection"] = "Rev. Sel.",
  ["Handcard selector"] = "Handcard selector, which is useful when have too many cards",

  ["Give Flower"] = "Flower",
  ["Give Egg"] = "Egg",
  ["Give Wine"] = "Wine",
  ["Give Shoe"] = "Shoe",
  ["Block Chatter"] = "Block chatter",
  ["Unblock Chatter"] = "Unblock chatter",
  ["Kick From Room"] = "Kick",
  --["Newbie"] = "新手保护ing",
  ["Win=%1 Run=%2 Total=%3"] = "Win=%1% Run=%2% Total=%3",
  ["Win=%1\nRun=%2\nTotal=%3"] = "Win: %1%\nRun: %2%\nTotal: %3",
  ["TotalGameTime: %1 min"] = "Played: %1 minutes",
  ["TotalGameTime: %1 h"] = "Played: %1 hours",

  ["Ban List"] = "Ban character scheme",
  ["List"] = "Scheme",
  -- ["New"] = "新建",
  -- ["Clear"] = "清空",
  ["Help_Ban_List"] = "The 'Export' button will copy this scheme to clipboard." ..
  "And the 'Import' button will read the clipboard and import scheme from it, or report an error.",
  -- ["Export"] = "导出",
  ["Export Success"] = "OK, you ban character schema has been copied to your clipboard.",
  -- ["Import"] = "导入",
  ["Not Legal"] = "Error: invalid JSON string.",
  ["Not JSON"] = "Error: improper JSON format.",
  ["Import Success"] = "Imported ban scheme successfully.",

  ["$OnlineInfo"] = "Lobby: %1, Online: %2",

  ["Generals Overview"] = "Characters",
  ["Cards Overview"] = "Cards",
  ["Special card skills:"] = "<b>Special use method:</b>",
  ["Every suit & number:"] = "<b>All suit and number:</b>",
  ["Scenarios Overview"] = "Game modes",
  -- ["Replay"] = "录像",
  -- ["Replay Manager"] = "来欣赏潇洒的录像吧！",
  ["Game Win"] = "Win",
  ["Game Lose"] = "Lose",
  ["Play the Replay"] = "Play",
  ["Delete Replay"] = "Delete",
  -- ["About"] = "关于",
  ["about_freekill_description"] = "<b>About FreeKill</b><br/>" ..
    "FreeKill is an open-source Bang!-like board game, which is aim to be extensive.<br/>" ..
    "<br/>Repo: https://github.com/Notify-ctrl/FreeKill",
  ["about_qt_description"] = "<b>About Qt</b><br/>" ..
    "Qt是一个C++图形界面应用程序开发框架，拥有强大的跨平台能力以及易于使用的API。<br/>" ..
    "<br/>本程序使用Qt 6.2+，主要利用QtQuick开发UI，同时也使用Qt的网络库开发服务端程序。<br/>" ..
    "<br/>官网： https://www.qt.io",
  ["about_lua_description"] = "<b>About Lua</b><br/>" ..
    "Lua是一种小巧、灵活、高效的脚本语言，广泛用于游戏开发中。<br/>" ..
    "<br/>本程序使用Lua 5.4，利用其完全实现了整个游戏逻辑。<br/>" ..
    "<br/>官网： https://www.lua.org",
  ["about_ossl_description"] = "<b>About OpenSSL</b><br/>" ..
    "OpenSSL是一个开源包，用来提供安全通信与各种加密支持。<br/>" ..
    "<br/>本程序目前用到了crypto库，以获得RSA加密算法支持。<br/>" ..
    "<br/>官网： https://www.openssl.org",
  ["about_gplv3_description"] = "<b>About GPLv3</b><br/>" ..
    "GNU通用公共许可协议（简称GPL）是一个广泛使用的自由软件许可证条款，它确保广大用户自由地使用、学习、共享或修改软件。<br/>" ..
    "<br/>由于Qt是按照GPLv3协议开源的库，与此同时本程序用到的readline库也属于GPLv3库，再加上QSanguosha也是以GPLv3协议开源的软件（从中借鉴了不少代码和思路），因此这个项目也使用GPLv3协议开源。<br/>" ..
    "<br/>官网： https://gplv3.fsf.org",
  ["about_sqlite_description"] = "<b>About SQLite</b><br/>" ..
    "SQLite是一个轻量级的数据库，具有占用资源低、运行效率快、嵌入性好等优点。<br/>" ..
    "<br/>FreeKill使用sqlite3在服务端保存用户的各种信息。<br/>" ..
    "<br/>官网： https://www.sqlite.org",
  ["about_git2_description"] = "<b>About Libgit2</b><br/>" ..
    "Libgit2是一个轻量级的、跨平台的、纯C实现的库，支持Git的大部分核心操作，并且支持几乎任何能与C语言交互的编程语言。<br/>" ..
    "<br/>FreeKill使用的是libgit2的C API，与此同时使用Git完成拓展包的下载、更新、管理等等功能。<br/>" ..
    "<br/>官网： https://libgit2.org",

  -- ["Exit Lobby"] = "退出大厅",

  -- ["OK"] = "确定",
  -- ["Cancel"] = "取消",
  -- ["End"] = "结束",
  -- ["Quit"] = "退出",
  ["BanGeneral"] = "Ban",
  ["ResumeGeneral"] = "Unban",
  ["BanPackage"] = "Ban packages",
  ["$BanPkgHelp"] = "Banning packages",
  ["$BanCharaHelp"] = "Banning characters",
  -- ["Companions"] = "珠联璧合",
  -- ["Death audio"] = "阵亡",
  -- ["Win audio"] = "胜利语音",
  -- ["Official"] = "官方",
  ["Title"] = "Title: ",
  ["Designer"] = "Designer: ",
  ["Voice Actor"] = "Voice Actor: ",
  ["Illustrator"] = "Illustrator: ",

  ["$WelcomeToLobby"] = "Welcome to FreeKill lobby!",
  ["GameMode"] = "Game mode: ",
  ["LuckCardNum"] = "Luck card count: ",
  ["ResponseTime"] = "Operation time (sec): ",
  ["GeneralBoxNum"] = "Character selection count: ",
  ["CardPackages"] = "Enabled card pacakges: ",
  ["IncludeFreeAssign"] = "<font color=\"red\">Free assign enabled</font>",
  ["IncludeDeputy"] = "<font color=\"red\">Deputy character enabled</font>",

  -- Room
  ["$EnterRoom"] = "Successfully entered the room.",
  ["#currentRoundNum"] = "Round #%1",
  ["$Choice"] = "%1: Please choose",
  ["$ChooseGeneral"] = "Please choose %1 character(s)",
  ["Same General Convert"] = "Convert character",
  -- ["Fight"] = "出战",
  ["Show General Detail"] = "View skills",

  ["#PlayCard"] = "Your turn now, please use a card",
  ["#AskForGeneral"] = "Please choose a character",
  ["#AskForSkillInvoke"] = "Do you want to use skill %1?",
  ["#AskForLuckCard"] = "Do you want to use luck card (%1 times left)?",
  ["AskForLuckCard"] = "Luck card",
  ["#AskForChoice"] = "%1: Please choose",
  ["#AskForChoices"] = "%1: Please choose",
  ["#choose-trigger"] = "Please choose the skill to use",
  ["trigger"] = "Trigger skill",
  -- ["Please arrange cards"] = "请拖拽移动卡牌",
  -- ["Please click to move card"] = "请点击移动卡牌",

  -- [" thinking..."] = " 思考中...",
  ["AskForGeneral"] = "Choosing character",
  ["AskForGuanxing"] = "Stargazing",
  ["AskForExchange"] = "Exchaging",
  ["AskForChoice"] = "Making choice",
  ["AskForChoices"] = "Making choice",
  ["AskForKingdom"] = "Choosing kingdom",
  ["AskForPindian"] = "Point fight",
  ["AskForMoveCardInBoard"] = "Moving cards",
  ["replaceEquip"] = "Replacing Equip",
  ["PlayCard"] = "Playing card",

  ["AskForCardChosen"] = "Choosing card",
  ["AskForCardsChosen"] = "Choosing card",
  ["#AskForChooseCard"] = "%1: please choose a card from %src",
  ["#AskForChooseCards"] = "%1: please choose %2~%3 cards from %src",
  ["$ChooseCard"] = "Choose a card",
  ["$ChooseCards"] = "Choose %1~%2 cards",
  ["$Hand"] = "Hand",
  ["$Equip"] = "Equip",
  ["$Judge"] = "Judge",
  ['$Selected'] = "Selected",
  ["#AskForUseActiveSkill"] = "Please use skill %1",
  ["#AskForUseCard"] = "Please use card %1",
  ["#AskForResponseCard"] = "Please play card %1",
  ["#AskForNullification"] = "Do you want to use Nullification to %arg that targets to %dest?",
  ["#AskForNullificationWithoutTo"] = "Do you want to use Nullification to %arg that used by %src?",
  ["#AskForPeaches"] = "%src is dying, please use %arg Peach(es) to save him",
  ["#AskForPeachesSelf"] = "You are dying, please use %arg Peach(es)/Alcohol to save yourself",

  ["#AskForDiscard"] = "Please discard %arg cards (%arg2 at least)",
  ["#AskForCard"] = "Please choose %arg cards (%arg2 at least)",
  ["#AskForDistribution"] = "Please distribute cards (%arg at least , %arg2 total)",
  ["@DistributionTo"] = "",
  ["#replaceEquip"] = "Please Choose a Equip Card to be replaced",
  ["#askForPindian"] = "%arg: please choose a hand card for point fight",
  ["#StartPindianReason"] = "%from started point fight (%arg)",
  ["#ShowPindianCard"] = "The point fight card of %from is %card",
  ["#ShowPindianResult"] = "%from %arg the point fight between %from and %to",
  ["pindianwin"] = "won",
  ["pindiannotwin"] = "lost",

  ["#ChooseInitialKingdom"] = "Please choose your kingdom in this game",

  ["#RevealGeneral"] = "%from revealed %arg %arg2",
  ["mainGeneral"] = "main character",
  ["deputyGeneral"] = "deputy character",
  ["seat#1"] = "Seat#1",
  ["seat#2"] = "Seat#2",
  ["seat#3"] = "Seat#3",
  ["seat#4"] = "Seat#4",
  ["seat#5"] = "Seat#5",
  ["seat#6"] = "Seat#6",
  ["seat#7"] = "Seat#7",
  ["seat#8"] = "Seat#8",
  ["seat#9"] = "Seat#9",
  ["seat#10"] = "Seat#10",
  ["seat#11"] = "Seat#11",
  ["seat#12"] = "Seat#12",
  ["@ControledBy"] = "Controller",

  -- ["Menu"] = "菜单",
  -- ["Surrender"] = "投降",
  -- ["Surrender is disabled in this mode"] = "投降在该模式不可用",
  -- ["Quit"] = "退出",
  -- ["Are you sure to quit?"] = "是否确认退出对局（若对局开始则将计入逃跑次数）？",

  -- ["Trust"] = "托管",
  ["Sort Cards"] = "Sort",
  -- ["Chat"] = "聊天",
  ["Log"] = "Game Log",
  -- ["Trusting ..."] = "托管中 ...",
  -- ["Observing ..."] = "旁观中 ...",

  ["#NoCardDraw"] = "Card Pile is empty",
  ["#NoGeneralDraw"] = "General Pile is empty",
  ["#NoEventDraw"] = "All game events terminated",
  ["#NoEnoughGeneralDraw"] = "No enough generals! (%arg/%arg2)",
  ["#TimeOutDraw"] = "It's over 9999 Round!",

  ["$GameOver"] = "Game Over",
  ["$Winner"] = "Winner is %1",
  ["$NoWinner"] = "Draw!",
  -- ["Back To Room"] = "回到房间",
  -- ["Back To Lobby"] = "返回大厅",
  -- ["Save Replay"] = "保存录像",

  ["Speed Resume"] = "Uniform",
  -- ["Speed Up"] = "加速",
  -- ["Speed Down"] = "减速",
  -- ["Pause"] = "暂停",
  -- ["Resume"] = "继续",

  ["Bulletin Info"] = [==[
    Hello, world!
  ]==],
}, "en_US")

-- Game concepts
Fk:loadTranslationTable({
  ["lord"] = "Lord",
  ["loyalist"] = "Loyalist",
  ["rebel"] = "Rebel",
  ["renegade"] = "Renegade",
  ["lord+loyalist"] = "Lord and Loyalist",

  ["normal_damage"] = "Normal",
  ["fire_damage"] = "Fire",
  ["thunder_damage"] = "Thunder",
  ["ice_damage"] = "Ice",
  ["hp_lost"] = "HP lost",
  ["lose_hp"] = "lose HP",

  ["phase_start"] = "Prepare phase",
  ["phase_judge"] = "Judge phase",
  ["phase_draw"] = "Draw phase",
  ["phase_play"] = "Action phase",
  ["phase_discard"] = "Discard phase",
  ["phase_finish"] = "Finish phase",

  -- ["chained"] = "横置",
  -- ["un-chained"] = "重置",
  ["reset-general"] = "reset",

  ["yang"] = "Yang",
  ["yin"] = "Yin",
  ["quest_succeed"] = "succeed",
  ["quest_failed"] = "failed",

  -- ["card"] = "牌",
  ["hand_card"] = "hand card",
  ["pile_draw"] = "draw pile",
  ["pile_discard"] = "discard pile",
  ["processing_area"] = "processing area",
  ["Pile"] = "pile",
  -- ["Top"] = "牌堆顶",
  -- ["Bottom"] = "牌堆底",
  -- ["Shuffle"] = "洗牌",

  ["general_card"] = "character card",
  ["General"] = "character",
  ["noGeneral"] = "no character",
  ["Hp"] = "HP",
  ["Damage"] = "DMG",
  ["Lost"] = "lost",
  ["Distance"] = "distance",
  ["Judge"] = "judge",
  ["Retrial"] = "retrial",

  ["_sealed"] = "Seal",
  ["weapon_sealed"] = "Weapon sealed",
  ["armor_sealed"] = "Armor sealed",
  ["treasure_sealed"] = "treasure sealed",

  ["WeaponSlot"] = "Weapon slot",
  ["ArmorSlot"] = "Armor slot",
  ["OffensiveRideSlot"] = "-1 horse slot",
  ["DefensiveRideSlot"] = "+1 horse slot",
  ["TreasureSlot"] = "Treasure slot",
  ["JudgeSlot"] = "Judge area",
}, "en_US")

-- related to sendLog
Fk:loadTranslationTable({
  -- game processing
  ["$AppendSeparator"] = '<font color="grey">------------------------------</font>',
  ["$GameStart"] = "== Game Started ==",
  ["$GameEnd"] = "== Game Over ==",

  -- get/lose skill
  ["#AcquireSkill"] = '%from acquired the skill "%arg"',
	["#LoseSkill"] = '%from lost the skill "%arg"',

  -- moveCards (they are sent by notifyMoveCards)
  ["$PutCard"] = "%arg card(s) of %from were put into draw pile",
  ["$PutKnownCard"] = "%card of %from were put into draw pile",
  ["$RemoveCardFromGame"] = "%arg2 card(s) were removed from game (as %arg)",
  ["$AddToPile"] = "%card were removed from game (as %arg)",
  ["$GetCardsFromPile"] = "%from got %arg2 card(s) %card from %arg",
  ["$DrawCards"] = "%from drew %arg card(s) %card",
  ["$PreyCardsFromPile"] = "%from got %arg card(s) %card",
  ["$GotCardBack"] = "%from took back %arg card(s) %card",
  ["$RecycleCard"] = "%from took back %arg card(s) %card from discard pile",
  ["$MoveCards"] = "%to got %arg card(s) %card from %from",
  ["$LightningMove"] = "%card transfered from %from to %to",
  ["$PasteCard"] = "%from used %card to %to",
  ["$DiscardCards"] = "%from discarded %arg card(s) %card",
  ["$DiscardOther"] = "%to discarded %arg card(s) %card from %from",
  ["$InstallEquip"] = "%from equipped %card",
  ["$UninstallEquip"] = "%from uninstalled %card",

  ["#ShowCard"] = "%from showed card(s) %card",
  ["#Recast"] = "%from recasted %card",
  ["#RecastBySkill"] = "%from recasted %card by %arg",

  -- phase
  ["#PhaseSkipped"] = "%from skipped %arg",
  ["#GainAnExtraTurn"] = "%from started to play an extra turn",
  ["#GainAnExtraPhase"] = "%from started to play an extra phase (%arg)",

  -- useCard
  ["#UseCard"] = "%from used card %card",
  ["#UseCardToTargets"] = "%from used card %card，and the target was %to",
  ["#CardUseCollaborator"] = "%from choosed %to as the sub-target of %arg",
  ["#UseCardToCard"] = "%from used card %card, and the target was %arg",
  ["#ResponsePlayCard"] = "%from played card %card",

  ["#UseVCard"] = "%from used card %card as %arg",
  ["#UseVCardToTargets"] = "%from used card %card as %arg, and the target was %to",
  ["#UseVCardToCard"] = "%from used card %card as %arg2, and the target was %arg",
  ["#ResponsePlayVCard"] = "%from played %card as %arg",
  ["#UseV0Card"] = "%from used %arg",
  ["#UseV0CardToTargets"] = "%from used %arg, target was %to",
  ["#UseV0CardToCard"] = "%from used %arg2，target was %arg",
  ["#ResponsePlayV0Card"] = "%from played %arg",

  ["#FilterCard"] = "Due to %arg, %arg2 that related to %from was regarded as %arg3",

  -- skill
  ["#InvokeSkill"] = '%from used skill "%arg"',

  -- judge
  ["#StartJudgeReason"] = "%from started a judgement (%arg)",
  ["#InitialJudge"] = "Judge card of %from was %arg",
  ["#ChangedJudge"] = "%from invoked %arg, retrialed judgement of %to with %arg2",
  ["#JudgeResult"] = "The judge result of %from was %arg",

  -- turnOver
  ["#TurnOver"] = "%from turned over character card, now his status is %arg",
	["face_up"] = "face up",
	["face_down"] = "face down",

  -- damage, heal and lose HP
  ["#Damage"] = "%to dealt %arg %arg2 DMG to %from",
  ["#DamageWithNoFrom"] = "%from took %arg %arg2 DMG",
  ["#LoseHP"] = "%from lost %arg HP",
  ["#HealHP"] = "%from healed %arg HP",
  ["#ShowHPAndMaxHP"] = "%from now has %arg HP (max HP = %arg2)",
  ["#LoseMaxHP"] = "%from lost %arg max HP",
  ["#HealMaxHP"] = "%from healed %arg max HP",

  -- dying and death
  ["#EnterDying"] = "%from is dying now",
  ["#KillPlayer"] = "%from [%arg] died, the killer was %to",
  ["#KillPlayerWithNoKiller"] = "%from [%arg] died without a killer",
  ["#Revive"] = "Wow, %from revived!",

  -- change hero
  ["#ChangeHero"] = "%from changed his %arg3 %arg to %arg2",

  -- misc
  ["#GuanxingResult"] = "The stargazing result of %from was %arg top, %arg2 bottom",
  ["#ChainStateChange"] = "%from %arg his character card",
  ["#ChainDamage"] = "%from is chained, so he will suffer damage too",
  ["#ChangeKingdom"] = "%from changed kingdom from %arg to %arg2",
}, "en_US")

-- card footnote
Fk:loadTranslationTable({
  ["$$DiscardCards"] = "%from discards",
  ["$$PutCard"] = "%from puts",

  ["##UseCard"] = "%from uses",
  ["##UseCardTo"] = "%from to %to",
  ["##ResponsePlayCard"] = "%from plays",
  ["##ShowCard"] = "%from shows",
  ["##JudgeCard"] = "%arg judge",
}, "en_US")
