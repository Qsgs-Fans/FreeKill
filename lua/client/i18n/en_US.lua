-- SPDX-License-Identifier: GPL-3.0-or-later

Fk:loadTranslationTable({
  -- Lobby
  -- ["Room List"] = "房间列表",
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

  -- ["Create Room"] = "创建房间",
  -- ["Room Name"] = "房间名字",
  ["$RoomName"] = "%1's room",
  ["Player num"] = "Player Count",
  -- ["Enable free assign"] = "自由选将",

  -- ["Generals Overview"] = "武将一览",
  -- ["Cards Overview"] = "卡牌一览",
  -- ["Scenarios Overview"] = "玩法一览",
  -- ["Replay"] = "录像",
  -- ["About"] = "关于",
  ["about_freekill_description"] = "<b>About FreeKill</b><br/>" ..
    "FreeKill is an open-source Bang!-like board game, which is aim to extensive.<br/>" ..
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

  ["$WelcomeToLobby"] = "Welcome to FreeKill lobby!",

  -- Room
  ["$EnterRoom"] = "Successfully entered the room.",
  ["$Choice"] = "%1: Please choose",
  ["$ChooseGeneral"] = "Please choose %1 general(s)",
  -- ["Fight"] = "出战",

  ["#PlayCard"] = "Your turn now, please use a card",
  ["#AskForGeneral"] = "",
  ["#AskForSkillInvoke"] = "Do you want to use skill %1?",
  ["#AskForChoice"] = "%1: Please choose",
  ["#choose-trigger"] = "Please choose the skill to use",
  ["trigger"] = "Trigger skill",
  -- ["Please arrange cards"] = "请拖拽移动卡牌",

  -- [" thinking..."] = " 思考中...",
  ["AskForGeneral"] = "Choosing general",
  ["AskForGuanxing"] = "Stargazing",
  ["AskForChoice"] = "Making choice",
  ["AskForPindian"] = "pindian",
  ["PlayCard"] = "Playing card",

  ["AskForCardChosen"] = "Choosing card",
  ["#AskForChooseCard"] = "%1：请选择其一张卡牌",
  ["$ChooseCard"] = "请选择一张卡牌",
  ["$Hand"] = "Hand",
  ["$Equip"] = "Equip",
  ["$Judge"] = "Judge",
  ["#AskForUseActiveSkill"] = "请使用技能 %1",
  ["#AskForUseCard"] = "请使用卡牌 %1",
  ["#AskForResponseCard"] = "请打出卡牌 %1",
  ["#AskForNullification"] = "是否为目标为 %dest 的 %arg 使用无懈可击？",
  ["#AskForNullificationWithoutTo"] = "是否对 %src 使用的 %arg 使用无懈可击？",

  ["#AskForDiscard"] = "请弃置 %arg 张牌，最少 %arg2 张",
  ["#askForPindian"] = "%arg：请选择一张手牌作为拼点牌",

  -- ["Trust"] = "托管",
  -- ["Sort Cards"] = "牌序",
  -- ["Chat"] = "聊天",
  ["Log"] = "Game Log",
  -- ["Trusting ..."] = "托管中 ...",
  -- ["Observing ..."] = "旁观中 ...",

  ["$GameOver"] = "Game Over",
  ["$Winner"] = "Winner is %1",
  -- ["Back To Lobby"] = "返回大厅",
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

  ["phase_judge"] = "Judge phase",
  ["phase_draw"] = "Draw phase",
  ["phase_play"] = "Play phase",
  ["phase_discard"] = "Discard phase",
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

  ["$DrawCards"] = "%from drew %arg card(s) %card",
  ["$DiscardCards"] = "%from discarded %arg card(s) %card",

  -- phase
  ["#PhaseSkipped"] = "%from skipped %arg",

  -- useCard
  ["#UseCard"] = "%from used card %card",
  ["#UseCardToTargets"] = "%from used card %card，and the target was %to",
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
  ["#InvokeSkill"] = '%from used skill "%arg"',

  -- judge
  ["#StartJudgeReason"] = "%from 开始了 %arg 的判定",
  ["#InitialJudge"] = "%from 的判定牌为 %card",
  ["#ChangedJudge"] = "%from 发动“%arg”把 %to 的判定牌改为 %card",
  ["#JudgeResult"] = "%from 的判定结果为 %card",

  -- turnOver
  ["#TurnOver"] = "%from 将武将牌翻面，现在是 %arg",
	["face_up"] = "face up",
	["face_down"] = "face down",

  -- damage, heal and lose HP
  ["#Damage"] = "%to 对 %from 造成了 %arg 点 %arg2 伤害",
  ["#DamageWithNoFrom"] = "%from 受到了 %arg 点 %arg2 伤害",
  ["#LoseHP"] = "%from 失去了 %arg 点体力",
  ["#HealHP"] = "%from 回复了 %arg 点体力",
  ["#ShowHPAndMaxHP"] = "%from 现在的体力值为 %arg，体力上限为 %arg2",

  -- dying and death
  ["#EnterDying"] = "%from 进入了濒死阶段",
  ["#KillPlayer"] = "%from [%arg] 阵亡，凶手是 %to",
  ["#KillPlayerWithNoKiller"] = "%from [%arg] 阵亡，无伤害来源",

  -- misc
  ["#GuanxingResult"] = "%from 的观星结果为 %arg 上 %arg2 下",
}, "en_US")
