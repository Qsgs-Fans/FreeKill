import QtQuick
import Fk
import LunarLtk

import LunarLtk.Models.Popups

// 试做型RoomModel
//
// 目标是干掉大部分游戏对局内UI页面/组件的property定义
// 他们只需要一个property RoomModel model就行了，剩下需要的数据从model拿
// 因此，model需要定义对局页面依赖的各种数据
//
// 然后，这个model再负责从Lua中及时取得最新数据。
//
// 预计还需要定义一系列signal
//
// 隔壁PhotoModel同理

QtObject {
  id: root

  property var roomPage

  property int playerNum        // 房间当前游玩人数
  property int dashboardId      // 初次开局时主视角id 用于保存主视角本来的玩家防止被切视角乱掉

  property int drawPileNum      // 牌堆剩余数
  property int roundCount       // 轮数
  property int playedTime       // 对局已经过的时长

  property list<PhotoModel> players: [] // 所有玩家的photo所需数据（包括自己的）

  // banners，细节与PhotoModel的marks一致。
  property list<var> banners: []

  // 我们主视角的数据在此
  property DashboardModel dashboard: DashboardModel {}

  property OptionsModel options

  // 处理区中的ui常驻卡牌
  property list<CardModel> processing: [];

  // 弃牌堆 仅用于展示
  property list<CardModel> discard: [];

  // ====== 活跃状态下的额外UI信息 ======

  // 几个大按钮
  property bool okCancelVisible: false // 确定取消可见？
  property bool okEnabled: false // 可以点确定按钮？
  property bool cancelEnabled: false // 可以点取消按钮？
  property bool endButtonVisible: false // 结束回合可见？
  property bool optionVisible: false // 结束回合可见？

  // 读条信息
  property real requestTotal // 总共的读条时长
  property real requestDuration // 剩余读条时长

  property string prompt

  property AGModel agModel

  // 俩跳过无懈用的
  property var skipNullificationData: null
  property var skippedUseEventIds: []
  readonly property bool canSkipNullification: {
    return !!skipNullificationData &&
    !skippedUseEventIds.find(id => id === skipNullificationData.useEventId)
  }

  readonly property string promptText: Ltk.processPrompt(prompt)

  signal seatChanged(); // 座位排序后的信号
  signal playerAdded(PhotoModel model); // 新玩家加入的信号（addNpc）
  signal cardsMoved(var move, var models); // 操作完移牌数据后通知ui
  signal popupReady(string command,var data, var model); // 准备好弹窗所需model后通知ui
  signal optionReady(var model)

  signal agReady(); // FIXME 烂完了五谷

  signal activated();
  signal deActivated();

  function getTimeString(time) {
    let s = time % 60;
    const m = (time - s) / 60;
    const h = (time - s - m * 60) / 3600;
    if (s < 10) s = '0' + s;
    return h ? `${h}:${m}:${s}` : `${m}:${s}`;
  }

  function getPhoto(pid) {
    for (const model of players) {
      if (model.playerid === pid) {
        return model;
      }
    }
  }

  function replyToServer(jsonData) {
    ClientInstance.replyToServer("", jsonData);
    deActivate();
  }

  function activate() {
    const dat = Backend.getRequestData();
    const total = dat["timeout"] * 1000;
    const now = Date.now(); // ms
    const elapsed = now - (dat["timestamp"] ?? now);

    if (total <= elapsed) {
      return;
    }

    requestTotal = total;
    requestDuration = total - elapsed;
    activated();
  }

  function deActivate() {
    okCancelVisible = false;
    okEnabled = false;
    cancelEnabled = false;
    endButtonVisible = false;
    prompt = "";
    skipNullificationData = null;

    dashboard.disableAllSkills();

    for (const model of players) {
      model.selected = false;
      model.state = "normal";
    }

    deActivated();
  }

  // 一秒5刷智慧
  function refreshData() {
    drawPileNum = Lua.ev("#ClientInstance.draw_pile");
    roundCount = Lua.client.getBanner("RoundCount") || 0;
    for (const model of players) {
      model.refreshData();
    }

    dashboard.refreshData();
  }

  function netStateChanged(sender, data) {
    let [id, state] = data;

    const model = getPhoto(id);
    if (!model) return;
    if (state === "run" && model.dead) {
      state = "leave";
    }
    model.netstate = state;
  }

  function arrangeSeats(_, order) {
    // 先重设座位号
    for (const model of players) {
      model.seatNumber = order.indexOf(model.playerid) + 1;
    }

    // 然后打散order，把Self放到第一个，这样才好调整model们的index以重排photo
    const selfIndex = order.indexOf(Cpp.self.id);
    const after = order.splice(selfIndex);
    after.push(...order);
    const photoOrder = after;

    for (const model of players) {
      model.index = photoOrder.indexOf(model.playerid);
    }

    seatChanged();
  }

  function propertyUpdate(_, data) {
    const [uid, property_name, value] = data;
    const model = getPhoto(uid);
    // FIXME: skins这边写成这样不太好看
    if (model && property_name in model) {
      model[property_name] = value;
    }
  }

  function startGame() {
    for (const model of players) {
      model.general = "";
    }
  }

  function setPlayerMark(_, data) {
    const [ id, mark, v ] = data;
    const player = getPhoto(id);
    Ltk.setMark(mark.startsWith("@!") ? player.picMarks : player.marks, mark, v, id);
  }

  function setCardMark(_, data) {
    const [ id, mark, v ] = data;
    for (const cd of [...processing, ...dashboard.handcards]) {
      if (cd.uniqueId === id) {
        Ltk.setMark(cd.marks, mark, v);
        cd.refreshData();
        return;
      }
    }
  }

  function setBanner(_, data) {
    const [ mark, v ] = data;
    Ltk.setMark(banners, mark, v);
  }

  function updateLimitSkill(sender, data) {
    const [ id, skill, time ] = data;
    getPhoto(id)?.updateLimitSkill(skill, time);
  }

  function addNpc(_, data) {
    const [id, name, avatar] = data;
    const photoModelComponent = Qt.createComponent("LunarLtk.Models", "PhotoModel");
    const model = photoModelComponent.createObject(null, {
      playerid: id,
      avatar,
      screenName: name,
      index: players.length,
    });
    model.index = players.length;
    players.push(model);
    playerNum++;
    playerAdded(model);
  }

  function moveCards(move, data) {
    const getCardsModel = (area, playerid) => {
      if (area === Ltk.Card.Processing) {
        return processing;
      } else if (area === Ltk.Card.DiscardPile) {
        return discard;
      } else if (area === Ltk.Card.PlayerHand && playerid === Cpp.self.id) {
        return dashboard.handcards;
      } else if (area === Ltk.Card.PlayerEquip) {
        return getPhoto(playerid)?.equips;
      } else if (area === Ltk.Card.PlayerJudge) {
        return getPhoto(playerid)?.delayedTricks;
      }
      return null;
    };

    const fromModel = getCardsModel(move.fromArea, move.from);
    const toModel = getCardsModel(move.toArea, move.to);

    const models = move.ids.map(id => {
      let card;
      if (fromModel) {
        const i = fromModel.findIndex(e => e.uniqueId === id);
        if (i !== -1) card = fromModel.splice(i, 1)[0];
      }
      return card || Ltk.createCardModel(id, { known: !!data[id.toString()] });
    });

    if (toModel) toModel.push(...models);

    cardsMoved(move, models);
  }

  function vanishDiscard(models) {
    discard = discard.filter(e => !models.includes(e));
  }

  function setCardFootnote(_, data) {
    const [id, note, virtual] = data;
    const v = processing.find(e => e[virtual ? "virtId" : "cardId"] === id)
    || discard.find(e => e[virtual ? "virtId" : "cardId"] === id);
    if (v) {
      v.footnote = note;
      v.footnoteVisible = true;
    }
  }

  function setCardVirtName(_, data) {
    const [ids, note, virtual] = data;
    ids.forEach(id => {
      const v = processing.find(e => e[virtual ? "virtId" : "cardId"] === id)
      || discard.find(e => e[virtual ? "virtId" : "cardId"] === id);
      if (v) v.virtName = note;
    });
  }

  function changeSelf() {
    // move new selfPhoto to dashboard
    let order = new Array(players.length);
    for (const model of players) {
      order[model.seatNumber - 1] = model.playerid;
    }
    arrangeSeats(null, order);

    // update dashboard
    dashboard.changeSelf();
  }

  function loseSkill(sender, data) {
    // jsonData: [ int player_id, string skill_name ]
    const [ id, skill_name, prelight ] = data;
    if (id === Cpp.self.id) {
      dashboard.loseSkill(skill_name, prelight);
    }
  }

  function addSkill(sender, data) {
    // jsonData: [ int player_id, string skill_name ]
    const [ id, skill_name, prelight ] = data;
    if (id === Cpp.self.id) {
      dashboard.addSkill(skill_name, prelight);
    }
  }

  function prelightSkill(sender, data) {
    const [ skill_name, prelight ] = data;
    dashboard.prelightSkill(skill_name, prelight);
  }

  function playerRunned(sender, data) {
    const [ runner, robot ] = data;

    const model = getPhoto(runner);
    if (model) {
      model.playerid = robot;
    }
  }

  function changeSkin(sender, data) {
    const photoModel = getPhoto(Number(data[0]));
    const skinData = photoModel.luaPlayer.skins;

    photoModel.skins = skinData;

    if (photoModel.playerid === dashboardId) {
      if (skinData.main) {
        Config.enabledSkins[photoModel.general] = skinData.main.name
      } else delete Config.enabledSkins[photoModel.general]
      if (skinData.deputy && photoModel.deputyGeneral) {
        Config.enabledSkins[photoModel.deputyGeneral] = skinData.deputy.name
      } else delete Config.enabledSkins[photoModel.deputyGeneral]

      if (photoModel.photoItem) {
        photoModel.photoItem?.changeSkinTimer?.start()
      }
    }
  }

  function syncSkins() {
    for (let model of players) {
      if (model.luaPlayer) {
        const skinData = model.luaPlayer.skins
        model.skins = skinData
      }
    }
  }

  function playCard() {
    skippedUseEventIds = [];
    activate();
    okCancelVisible = true;
  }

  function askForSkillInvoke(sender, data) {
    const [ skill, prompt ] = data;
    root.prompt = prompt || `#AskForSkillInvoke:::${skill}`;
    activate();
  }

  function askForUseActiveSkill(sender, data) {
    const [ skill_name, prompt, cancelable ] = data;
    root.prompt = prompt || `#AskForUseActiveSkill:::${skill_name}`;
    activate();
    okCancelVisible = true;
  }

  function askForResponseCard(sender, data) {
    const [ cardname, pattern, prompt, cancelable, extra_data, disabledSkillNames ] = data;

    root.prompt = prompt || `#AskForResponseCard:::${cardname}`;
    activate();
    okCancelVisible = true;
  }

  function askForUseCard(sender, data) {
    const [ cardname, pattern, prompt, cancelable, nullfiData, disabledSkillNames ] = data;

    root.prompt = prompt || `#AskForUseCard:::${cardname}`;

    if (nullfiData) {
      // 询问使用【无懈可击】相关

      // 不对自己使用的单目标锦囊牌无懈
      if (Config.noSelfNullification && nullfiData.effectFrom === Cpp.self.id &&
      !Ltk.getCardData(nullfiData.effectCardId).multiple_targets) {
        Lua.updateRequestUI("Button", "Cancel");
        return;
      }

      // 如果已忽略本轮无懈可击，那么忽略，除非即将对自己生效
      if (nullfiData.effectTo !== Cpp.self.id &&
      skippedUseEventIds.find(id => id === nullfiData.useEventId)) {
        Lua.updateRequestUI("Button", "Cancel");
        return;
      }

      if (nullfiData.useEventId && nullfiData.effectTo) {
        skipNullificationData = nullfiData;
      }
    }

    activate();
    okCancelVisible = true;
  }

  function askForArrangeCards(sender, data) {
    const { cards, prompt, size, capacities, limits, is_free, names, pattern, poxi_type, cancelable } = data;
    const modelComponent = Qt.createComponent("LunarLtk.Models.Popups", "ArrangeCardsModel");
    const model = modelComponent.createObject(null, {
      origCards: cards,
      prompt,
      size,
      areaCapacities: capacities,
      areaLimits: limits,
      areaNames: names,
      pattern: pattern,
      poxiType: poxi_type,
      cancelable: cancelable,
    });
    model.initializeCards();
    model.accepted.connect(() => replyToServer(model.result));
    model.rejected.connect(() => replyToServer([]));
    activate();
    popupReady(Command.AskForArrangeCards, data, model);
  }

  function askForChoices(sender, data) {
    const [ choices, all_choices, [ min_num, max_num], cancelable, skill_name, prompt, detailed, single ] = data;
    root.prompt = prompt || `#AskForChoice:::${skill_name}`;
    activate();
    const modelComponent = Qt.createComponent("LunarLtk.Models.Popups", "ChoicesModel");
    const model = modelComponent.createObject(null, {
      choices,
      allChoices: all_choices,
      minNum: min_num,
      maxNum: max_num,
      cancelable,
      skillName: skill_name,
      prompt,
      detailed,
      single,
    });
    model.accepted.connect(() => replyToServer(model.result));
    model.rejected.connect(() => replyToServer([]));
    popupReady(Command.AskForChoices, data, model);
  }

  function askForOptions(sender, data) {
    const [ options, all_options, [ min_num, max_num], cancelable, skill_name, prompt, single ] = data;
    root.prompt = prompt || `#AskForOption:::${skill_name}`;
    activate();
    const modelComponent = Qt.createComponent("LunarLtk.Models", "OptionsModel");
    const model = modelComponent.createObject(null, {
      options,
      allOptions: all_options,
      minNum: min_num,
      maxNum: max_num,
      cancelable,
      skillName: skill_name,
      prompt,
      single,
    });
    model.accepted.connect(() => replyToServer(model.result));
    model.rejected.connect(() => replyToServer([]));
    root.options = model;
    optionVisible = true;
    optionReady(model)
  }

  function askForGeneral(sender, data) {
    const [generals, n, no_convert, heg, rule, prompt, extra_data] = data;
    const modelComponent = Qt.createComponent("LunarLtk.Models.Popups", "ChooseGeneralModel");
    const model = modelComponent.createObject(null, {
      generals,
      choiceNum: n ?? 1,
      prompt: prompt ?? "",
      convertDisabled: !!Lua.client.getSettings("disableSameConvert") || !!no_convert,
      hegemony: !!heg,
      ruleType: rule ?? (heg? "heg_general_choose" : "askForGeneralsChosen"),
      extraData: extra_data ?? { n : n },
    });
    model.initGeneralModels();
    model.accepted.connect(() => replyToServer(model.result));
    model.rejected.connect(() => replyToServer([]));
    activate();
    popupReady(Command.AskForGeneral, data, model);
  }

  function askForPoxi(sender, dat) {
    const { type, data, extra_data, cancelable } = dat;
    const modelComponent = Qt.createComponent("LunarLtk.Models.Popups", "PoxiModel");
    const model = modelComponent.createObject(null, {
      poxiType: type,
      cardData: data,
      cancelable,
      extraData: extra_data,
    });
    model.accepted.connect(() => replyToServer(model.selectedIds));
    model.rejected.connect(() => replyToServer([]));
    activate();
    popupReady(Command.AskForPoxi, dat, model);
  }

  function askForMoveCardInBoard(sender, data) {
    const { cards, cardsPosition, playerIds } = data;
    const modelComponent = Qt.createComponent("LunarLtk.Models.Popups", "MoveCardInBoardModel");
    const model = modelComponent.createObject(null, {
      cardIds: cards,
      cardsPosition,
      playerIds,
    });
    model.accepted.connect(() => replyToServer({
      cardId: model.result,
      pos: cardsPosition[cards.indexOf(model.result)],
    }));
    activate();
    popupReady(Command.AskForMoveCardInBoard, data, model);
  }

  function askForCardChosen(sender, data) {
    const { card_data, prompt, visible_data } = data;
    const modelComponent = Qt.createComponent("LunarLtk.Models.Popups", "PlayerCardModel");
    const model = modelComponent.createObject(null, {
      prompt: prompt,
      cardData: card_data,
      cardVisibility: visible_data,
    });
    model.accepted.connect(() => replyToServer(model.selectedId));
    model.rejected.connect(() => replyToServer(""));
    activate();
    popupReady(Command.AskForCardChosen, data, model);
  }

  function askForCardsAndChoice(sender, data) {
    const { cards, choices, prompt, cancel_choices, min, max, filter_skel, disabled, extra_data } = data;
    const modelComponent = Qt.createComponent("LunarLtk.Models.Popups", "ChooseCardsAndChoiceModel");
    const model = modelComponent.createObject(null, {
      cards,
      choices,
      prompt,
      cancelChoices: cancel_choices ?? [],
      minNum: min ?? 1,
      maxNum: max ?? 1,
      filterSkel: filter_skel ?? "",
      disabledCards: disabled ?? [],
      extraData: extra_data,
    });
    model.accepted.connect(() => replyToServer(model.result));
    model.rejected.connect(() => replyToServer(""));
    activate();
    popupReady(Command.AskForCardsAndChoice, data, model);
  }

  function gameOver(sender, jsonData) {
    const modelComponent = Qt.createComponent("LunarLtk.Models.Popups", "GameOverModel");
    const model = modelComponent.createObject();
    model.winner = jsonData;
    deActivate();
    popupReady(Command.GameOver, jsonData, model);
  }

  function customDialog(sender, data) {
    const { component } = data;
    activate();
    if (component.model) {
      const mod =Lua.createQmlObject(component.model);
      mod.accepted.connect(() => replyToServer(mod.result));
      mod.rejected.connect(() => replyToServer(""));
      popupReady(Command.CustomDialog, data, mod);
    } else {
      popupReady(Command.CustomDialog, data, null);
    }
  }

  function miniGame(sender, data) {
    // console.log("miniGame", data.type, JSON.stringify(data.data));
    const game = data.type;
    const dat = data.data;
    const gdata = Ltk.getMiniGame(game, Cpp.self.id, JSON.stringify(dat));

    const CustomDialogData = {
      component: { url: gdata.qml_path + ".qml" },
      model: gdata.model,
      data: dat
    };
    activate();
    if (CustomDialogData.model) {
      // console.log("miniGame model creating", JSON.stringify(CustomDialogData.model));
      const mod = Lua.createQmlObject(CustomDialogData.model);
      const modFunc = mod.initialize;
      if (typeof modFunc === "function") {
        modFunc.call(mod);
      }
      mod.accepted.connect(() => replyToServer(mod.result));
      mod.rejected.connect(() => replyToServer(""));
      popupReady(Command.MiniGame, CustomDialogData, mod);
    } else {
      popupReady(Command.MiniGame, CustomDialogData, null);
    }
  }

  function fillAG(sender, data) {
    const ids = data[0];

    const modelComponent = Qt.createComponent("LunarLtk.Models.Popups", "AGModel");
    const model = modelComponent.createObject();
    model.addIds(ids);
    model.accepted.connect(() => dataModel.replyToServer(model.result));

    agModel = model;
    agReady();
  }

  function askForAG(sender, j) {
    activate();
    agModel.interactive = true;
  }

  function takeAG(sender, data) {
    if (!agModel) return;
    const pid = data[0];
    const cid = data[1];
    const item = getPhoto(pid);
    const general = Lua.tr(item.general);

    agModel.takeAG(general, cid);
  }

  function disableAG(sender, data) {
    if (!agModel) return;
    agModel.interactive = false;
  }

  // 蒋琬专属；啥时候删了这玩意啊？
  function jiangwanHandler(sender, data) {
    const hand = dashboard.handcards.map(c => c.cardId);
    replyToServer(hand);
  }

  function skipNullification() {
    skippedUseEventIds.push(skipNullificationData.useEventId);
    Lua.updateRequestUI("Button", "Cancel");
  }

  // 确定只会修改model属性的逻辑都搬家到这里
  function setupCallbacks() {
    roomPage.addCallback(Command.NetStateChanged, netStateChanged);
    roomPage.addCallback(Command.ArrangeSeats, arrangeSeats);
    roomPage.addCallback(Command.PropertyUpdate, propertyUpdate);
    roomPage.addCallback(Command.StartGame, startGame);
    roomPage.addCallback(Command.SetPlayerMark, setPlayerMark);
    roomPage.addCallback(Command.SetBanner, setBanner);
    roomPage.addCallback(Command.UpdateLimitSkill, updateLimitSkill);
    roomPage.addCallback(Command.MoveCards, (_, data) => {
      for (const move of data.merged) moveCards(move, data);
    });
    roomPage.addCallback(Command.SetCardFootnote, setCardFootnote);
    roomPage.addCallback(Command.SetCardVirtName, setCardVirtName);
    roomPage.addCallback(Command.ChangeSelf, changeSelf);
    roomPage.addCallback(Command.LoseSkill, loseSkill);
    roomPage.addCallback(Command.AddSkill, addSkill);
    roomPage.addCallback(Command.PrelightSkill, prelightSkill);
    roomPage.addCallback("AddNpc", addNpc);

    roomPage.addCallback(Command.EmptyRequest, activate);
    roomPage.addCallback(Command.CancelRequest, deActivate);
    roomPage.addCallback(Command.PlayerRunned, playerRunned);
    roomPage.addCallback(Command.ChangeSkin, changeSkin);

    roomPage.addCallback(Command.SetCardMark, setCardMark);
    roomPage.addCallback(Command.GetPlayerHandcards, jiangwanHandler);

    // 以下为交互类
    roomPage.addCallback(Command.PlayCard, playCard);
    roomPage.addCallback(Command.AskForSkillInvoke, askForSkillInvoke);
    roomPage.addCallback(Command.AskForUseActiveSkill, askForUseActiveSkill);
    roomPage.addCallback(Command.AskForResponseCard, askForResponseCard);
    roomPage.addCallback(Command.AskForUseCard, askForUseCard);

    roomPage.addCallback(Command.AskForChoices, askForChoices);
    roomPage.addCallback(Command.AskForOptions, askForOptions);
    roomPage.addCallback(Command.AskForGeneral, askForGeneral);
    roomPage.addCallback(Command.AskForPoxi, askForPoxi);
    roomPage.addCallback(Command.AskForArrangeCards, askForArrangeCards);
    roomPage.addCallback(Command.AskForMoveCardInBoard, askForMoveCardInBoard);
    roomPage.addCallback(Command.AskForCardChosen, askForCardChosen);
    roomPage.addCallback(Command.AskForCardsAndChoice, askForCardsAndChoice);
    roomPage.addCallback(Command.GameOver, gameOver);
    roomPage.addCallback(Command.CustomDialog, customDialog);
    roomPage.addCallback(Command.MiniGame, miniGame);

    roomPage.addCallback(Command.FillAG, fillAG);
    roomPage.addCallback(Command.AskForAG, askForAG);
    roomPage.addCallback(Command.TakeAG, takeAG);
    roomPage.addCallback(Command.DisableAG, disableAG);

    roomPage.addCallback(Command.ReplyToServer, (_, data) => replyToServer(data));
  }

  function applyChange(uiUpdate) {
    const pdatas = uiUpdate["Photo"];
    pdatas?.forEach(pdata => {
      const model = getPhoto(pdata.id);
      model.state = pdata.state;
      model.selectable = pdata.enabled;
      model.selected = pdata.selected;
    });
    for (const model of players) {
      model.updateTargetTip();
    }

    const buttons = uiUpdate["Button"];
    if (buttons) {
      okCancelVisible = true;
    }
    buttons?.forEach(bdata => {
      switch (bdata.id) {
        case "OK":
        okEnabled = bdata.enabled;
        if (optionVisible && options) options.acceptable = bdata.enabled;
        break;
        case "Cancel":
        cancelEnabled = bdata.enabled;
        if (optionVisible && options) options.cancelable = bdata.enabled;
        break;
        case "End":
        endButtonVisible = bdata.enabled;
        break;
      }
    });
  }

  function initialize() {
    dashboardId = Cpp.self.id;
    const luaPlayers = Lua.client.players;
    playerNum = luaPlayers.length;
    for (const player of luaPlayers) {
      const dat = player.__toqml().model;
      delete dat.prop.selectable;
      delete dat.prop.state;
      const model = Lua.createQmlObject(dat);
      model.index = players.length;
      players.push(model);
    }
  }
}
