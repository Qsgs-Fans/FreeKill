import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

import Fk
import Fk.Components.Common
import Fk.Widgets as W

import LunarLtk
import LunarLtk.Components
import LunarLtk.Components.Photo as PhotoElement

// Room系页面的公共代码（大概）
// 反正放不可见元素就好了

W.PageBase {
  id: roomScene

  property var agItem // 五谷框
  property var popupItem // 弹窗
  property alias dataModel: dataModel
  property alias bigAnim: bigAnim
  property alias bgm: bgm
  property alias infoPopup: infoPopup

  property alias photoModel: photoModel

  property alias dynamicCardArea: dynamicCardArea

  // required property 区 - 所有自定义ui都要填写它们
  required property Item roomArea
  required property Item progress
  required property Animation progressAnim
  required property var skillInteraction
  required property var dashboard

  required property Item drawPile
  required property Item tablePile

  ListModel {
    id: photoModel

    signal modelDataChanged()

    onDataChanged: modelDataChanged()
    onRowsInserted: modelDataChanged()
    onRowsRemoved: modelDataChanged()
  }

  RoomModel {
    id: dataModel
    roomPage: roomScene

    onSeatChanged: roomScene.arrangePhotos();
    onPlayerAdded: model => {
      roomScene.photoModel.append({ modelData: model });
    };
    onCardsMoved: (move, data) => roomScene.moveCards(move, data);

    onActivated: roomScene.handleOnActivated()

    onDeActivated: roomScene.handleOnDeActivated()

    onPopupReady: (command, data, model) => roomScene.handleOnPopupReady(command, data, model)

    onAgReady: roomScene.showAG();
  }

  MediaPlayer {
    id: bgm
    source: Config.bgmFile

    loops: MediaPlayer.Infinite
    onPlaybackStateChanged: {
      if (playbackState == MediaPlayer.StoppedState)
        play();
    }
    audioOutput: AudioOutput {
      volume: Config.bgmVolume / 100
    }
  }

  W.PopupItem {
    id: infoPopup
    width: Config.winWidth * 0.60
    height: Config.winHeight * 0.8
    anchors.centerIn: parent
    background: Rectangle {
      color: "#CC2E2C27"
      radius: 5
      border.color: "#A6967A"
      border.width: 1
    }
  }

  Loader {
    id: bigAnim
    anchors.fill: parent
    z: 999
  }

  Item {
    id: dynamicCardArea
    anchors.fill: parent
    z: 2
  }


  Shortcut {
    sequence: "D"
    property bool show_distance: false
    onActivated: {
      show_distance = !show_distance;
      roomScene.showDistance(show_distance);
    }
  }

  Shortcut {
    sequence: "Return"
    enabled: dataModel.okEnabled && !dataModel.optionVisible
    onActivated: Lua.updateRequestUI("Button", "OK");
  }

  Shortcut {
    sequence: "Space"
    enabled: dataModel.cancelEnabled || endPhaseButton.visible;
    onActivated: if (dataModel.cancelEnabled) {
      Lua.updateRequestUI("Button", "Cancel");
    } else {
      dataModel.replyToServer("");
    }
  }

  Timer {
    id: statusSkillTimer
    interval: 200
    running: true
    repeat: true
    onTriggered: roomScene.handleRefreshData()
  }

  // ==== function 区 ====

  function initializeRoom() {
    dataModel.initialize();
    setupCallbacks();

    for (let i = 0; i < dataModel.playerNum; i++) {
      photoModel.append({ modelData: dataModel.players[i] });
    }

    bgm.play();

    Ltk.roomScene = this;
    Ltk.roomModel = dataModel;

    arrangePhotos();
  }

  function cancelAllFocus() {
    for (const model of dataModel.players) {
      const item = model.photoItem;
      item.progressBar.visible = false;
      item.progressTip = "";
    }
  }

  function moveFocus(sender, data) {
    const [ focuses, command ] = data;
    const timeout = data[2] ?? (Config.roomTimeout * 1000);

    cancelAllFocus();

    let item, model;
    for (const pid of focuses) {
      const model = dataModel.getPhoto(pid);
      if (!model) continue;
      // 这样其实不好。应该用signal从model传递到item，或者item建立绑定
      const item = model.photoItem;
      item.progressBar.duration = timeout;
      item.progressBar.visible = true;
      item.progressTip = Lua.tr(command)
        + Lua.tr(" thinking...");
    }
  }

  function handleOnActivated() {
    roomScene.progressAnim.from = (dataModel.requestDuration / dataModel.requestTotal) * 100.0;
    roomScene.progressAnim.duration = dataModel.requestDuration;
    roomScene.progress.visible = true;
  }

  function handleOnDeActivated() {
    roomScene.skillInteraction.item?.clear();
    roomScene.skillInteraction.sourceComponent = undefined;
    roomScene.progress.visible = false;

    roomScene.dashboard.disableAllCards();
    roomScene.dashboard.clearVisiblePile();

    if (roomScene.popupItem != null) {
      roomScene.popupItem.finished();
    }

    if (dataModel.options) {
      dataModel.options.destroy();
      dataModel.options = null;
    }
    dataModel.optionVisible = false;
    Ltk.roomScene.dashboard.handcardArea.clearMiscExpand();

    Lua.finishRequestUI();
    applyChange({});
  }

  function handleRefreshData() {
    //ai说游戏结束别刷了
    if (!Lua.client.gameStarted) {
      return;
    }
    dataModel.refreshData();
    Ltk.refreshStatusSkills();
    // 刷托管按钮
    trustBtn.enabled = true;
  }

  function handleOnPopupReady(command, data, model) {
    let component;
    let prop = { dataModel: model };
    if (!model) delete prop.dataModel;

    const componentTable = {
      [Command.AskForArrangeCards]: "ArrangeCardsBox",
      [Command.AskForChoices]: "ChoicesBox",
      [Command.AskForGeneral]: "ChooseGeneralBox",
      [Command.AskForCardChosen]: "PlayerCardBox",
      [Command.AskForPoxi]: "PoxiBox",
      [Command.AskForMoveCardInBoard]: "MoveCardInBoardBox",
      [Command.AskForCardsAndChoice]: "ChooseCardsAndChoiceBox",

      [Command.GameOver]: "GameOverBox",
    };

    let needLoadData = null;
    if (command == Command.CustomDialog) {
      component = Lua.createComponent(data.component);
      if (model) {
        model?.initialize()
      } else {
        Object.assign(prop, data.component?.prop ?? {});
      }
    } else if (command == Command.MiniGame) {
      if (data.model) {
        component = Lua.createComponent(data.component);
        // console.log(component.status, component.errorString());
        Object.assign(prop, data.data?.prop ?? {});
      } else { // 兼容旧版
        component = Qt.createComponent(Cpp.path + "/" + data.component.url);
        needLoadData = data.data;
      }
    } else {
      component = Qt.createComponent("LunarLtk.Pages.Popups", componentTable[command]);
    }

    roomScene.showPopup(component, prop);
    if (needLoadData) roomScene.popupItem.loadData(needLoadData); // 兼容旧版

    if (roomScene.popupItem.timeout) {
      roomScene.progress.visible = false;
    }
  }

  function doIndicate(from, tos) {
    const component = Qt.createComponent("LunarLtk.Components", "IndicatorLine");
    if (component.status !== Component.Ready)
      return;

    const fromItem = getPhotoOrDashboard(from);
    const fromPos = mapFromItem(fromItem, fromItem.width / 2,
                                fromItem.height / 2);

    const end = [];
    for (let i = 0; i < tos.length; i++) {
      if (from === tos[i])
        continue;
      const toItem = getPhotoOrDashboard(tos[i]);
      const toPos = mapFromItem(toItem, toItem.width / 2, toItem.height / 2);
      end.push(toPos);
    }

    const color = "#96943D";
    const line = component.createObject(roomScene, { start: fromPos, end: end, color: color });
    line.finished.connect(line.destroy);
    line.running = true;
  }

  function setPicEmotion(id, path, permanent) {
    const photo = getPhoto(id);
    if (!photo) return;
    photo.setEmotion(path, permanent);
  }

  function setEmotion(id, emotion, isCardId, permanent) {
    let path = Fs.convertUrlToPath(SkinBank.pixAnimDir + emotion);
    if (!Fs.exists(path) && !Fs.exists(path + ".png")) {
      path = Fs.convertUrlToPath(`${Cpp.path}/${emotion}`);
    }
    if (!Fs.exists(path)) {
      if (Fs.exists(path + ".png") && !isCardId) {
        setPicEmotion(id, path + ".png", permanent);
      }
      return;
    }

    if (!Fs.isDir(path)) {
      return;
    }

    const component = Qt.createComponent("LunarLtk.Components", "PixmapAnimation");
    if (component.status !== Component.Ready) {
      return;
    }

    let photo;
    if (isCardId === true) {
      const modelFinder = v => v.uniqueId === id;
      const m = dataModel.processing.find(modelFinder) || dataModel.discard.find(modelFinder);
      if (m) photo = m.cardItem;
    } else {
      photo = getPhoto(id);
    }
    if (!photo) return;

    const animation = component.createObject(photo, {
      source: (Cpp.os === "Win" ? "file:///" : "") + path,
      scale: 0.75,
    });
    animation.anchors.centerIn = photo;
    if (isCardId) {
      animation.started.connect(() => photo.busy = true);
      animation.finished.connect(() => {
        photo.busy = false;
        animation.destroy()
      });
    } else {
      animation.finished.connect(animation.destroy);
    }
    animation.start();
  }

  function hideEmotion(playerId) {
    const photo = getPhoto(playerId);
    if (!photo) {
      return;
    }

    photo.hideEmotion();
  }

  function doSuperLightBox(path, data) {
    if (path) {
      bigAnim.source = Cpp.path + "/" + path;
    } else {
      bigAnim.sourceComponent = Qt.createComponent("LunarLtk.Components", "SuperLightBox");
    }
    if (data && bigAnim.item && typeof bigAnim.item.loadData === "function") {
      bigAnim.item.loadData(data);
    }
  }

  function notifySkillInvoked(playerId, skillName, skillType) {
    const photo = getPhoto(playerId);
    if (!photo) {
      return;
    }

    const component = Qt.createComponent("LunarLtk.Components", "SkillInvokeAnimation");
    if (component.status !== Component.Ready) {
      return;
    }

    const animation = component.createObject(photo, { skillName: Lua.tr(skillName), skillType: skillType });
    animation.anchors.centerIn = photo;
    animation.finished.connect(animation.destroy);
  }

  function notifyUltSkillInvoked(playerId, skillName, isDeputy) {
    const photo = getPhoto(playerId);
    if (!photo) {
      return;
    }

    bigAnim.sourceComponent = Qt.createComponent("LunarLtk.Components", "UltSkillAnimation");
    bigAnim.item.loadData({
      skillName,
      general: isDeputy ? photo.deputyGeneral : photo.general,
    });
  }

  function doAnimate(sender, data) {
    switch (data.type) {
      case "Indicate":
        data.to.forEach(item => {
          doIndicate(data.from, [item[0]]);
          if (item[1]) {
            doIndicate(item[0], item.slice(1));
          }
        })
        break;
      case "Emotion":
        setEmotion(data.player, data.emotion, data.is_card, data.permanent);
        break;
      case "HideEmotion":
        hideEmotion(data.player);
        break;
      case "SuperLightBox": {
        doSuperLightBox(data.path, data.data);
        break;
      }
      case "InvokeSkill": {
        notifySkillInvoked(data.player, data.name, data.skill_type || "special",);
        break;
      }
      case "InvokeUltSkill": {
        notifyUltSkillInvoked(data.player, data.name, data.deputy);
        break;
      }
      default:
        break;
    }
  }

  function playDamageEffect(playerId, damageType, damageNum) {
    const photo = getPhoto(playerId);
    if (!photo) {
      return;
    }

    setEmotion(playerId, "damage");
    photo.tremble();
    Backend.playSound("./audio/system/" + damageType + (damageNum > 1 ? "2" : ""));
  }

  function playLoseHpEffect() {
    Backend.playSound("./audio/system/losehp");
  }

  function playChangeMaxEffect(data) {
    if (data.num < 0) {
      Backend.playSound("./audio/system/losemaxhp");
    }
  }

  function playGeneralSkillSound(skill, idx, general) {
    if (!general) {
      return false;
    }

    const dat = Ltk.getGeneralData(general);
    const extension = dat.extension;
    const path = SkinBank.getAudio(skill + "_" + general, extension, "skill");
    if (path) {
      Backend.playSound(path, idx);
      return true;
    }
  }

  function playSkillSound(skill, idx, general, deputy) {
    if (playGeneralSkillSound(skill, idx, general)) {
      return;
    }

    if (playGeneralSkillSound(skill, idx, deputy)) {
      return;
    }

    const dat = Ltk.getSkillData(skill);
    const path = SkinBank.getAudio(skill, dat.extension, "skill");
    Backend.playSound(path, idx);
  }

  function playSound(path) {
    const _path = SkinBank.getAudioByPath(path);
    Backend.playSound(_path);
  }

  function playDeathSound(playerId) {
    const photo = getPhoto(playerId);
    if (!photo) {
      return;
    }
    const general = photo.general;
    const extension = Ltk.getGeneralData(general).extension;
    const path = SkinBank.getAudio(general, extension, "death");
    Backend.playSound(path);
  }

  function logEvent(sender, data) {
    switch (data.type) {
      case "Damage": {
        playDamageEffect(data.to, data.damageType || "normal_damage", data.damageNum);
        break;
      }
      case "LoseHP": {
        playLoseHpEffect();
        break;
      }
      case "ChangeMaxHp": {
        playChangeMaxEffect(data);
        break;
      }
      case "PlaySkillSound": {
        playSkillSound(data.name, data.i, data.general, data.deputy);
        break;
      }
      case "PlaySound": {
        playSound(data.name);
        break;
      }
      case "Death": {
        playDeathSound(data.to);
        break;
      }
      default:
        break;
    }
  }


  function showAG() {
    const component = Qt.createComponent("LunarLtk.Pages.Popups", "AG");
    const item = component.createObject(roomScene, { dataModel: dataModel.agModel });
    item.z = 1000;
    agItem = item;

    const moveToCenter = () => {
      item.x = Math.round((roomArea.width - item.width) / 2);
      item.y = Math.round(roomArea.height * 0.67 - item.height / 2);
    }

    item.finished.connect(() => {
      item.destroy();
      roomScene.agItem = null;
    });
    item.widthChanged.connect(() => moveToCenter());
    item.heightChanged.connect(() => moveToCenter());

    moveToCenter();
  }

  function showPopup(component, prop) {
    const item = component.createObject(roomScene, prop);
    item.z = 1000;
    if (popupItem) {
      popupItem?.finished();
    }
    popupItem = item;

    const moveToCenter = () => {
      item.x = Math.round((roomArea.width - item.width) / 2);
      item.y = Math.round(roomArea.height * 0.67 - item.height / 2);
    }

    item.finished.connect(() => {
      roomScene.popupItem = null;
      if (item.outAnim) {
        item.outAnim.start();
        item.outAnim.finished.connect(() => {
          item.destroy();
        });
      } else {
        item.destroy();
      }
    });
    item.widthChanged.connect(() => moveToCenter());
    item.heightChanged.connect(() => moveToCenter());

    moveToCenter();

    item.showAnim?.start();
    item?.shown();
  }

  function showInfoPopup(component, prop) {
    infoPopup.setSourceComponent(component, prop);
    infoPopup.open();
  }

  function closeInfoPopup() {
    infoPopup.close();
  }

  function getPhoto(id) {
    return dataModel.getPhoto(id)?.photoItem;
  }

  function getPhotoOrDashboard(id) {
    if (id === Cpp.self.id) return dashboard;
    return getPhoto(id);
  }


  function applyChange(uiUpdate) {
    const sskilldata = uiUpdate["SpecialSkills"]?.[0]
    if (sskilldata) {
      specialCardSkills.model = sskilldata?.skills ?? [];
    }

    dataModel.applyChange(uiUpdate);
    dashboard.applyChange(uiUpdate);

    // Interaction最后上桌 太给脸了居然插结
    for (const data of (uiUpdate["_delete"] || [])) {
      if (data.type !== "Interaction") continue;
      skillInteraction.item?.clear();
      skillInteraction.sourceComponent = undefined;
      if (roomScene.popupItem)
      roomScene.popupItem.finished();
      if (dataModel.options) {
        dataModel.options.destroy();
        dataModel.options = null;
      }
      dataModel.optionVisible = false;
      Ltk.roomScene.dashboard.handcardArea.clearMiscExpand();
    }
    for (const dat of (uiUpdate["_new"] || [])) {
      if (dat.type !== "Interaction") continue;
      const data = dat.data.spec;
      const skill_name = dat.data.skill_name;
      switch (data.type) {
      case "combo":
      case "checkbox":
      case "cardname":
        const pages = {
          "combo": "SkillCombo",
          "checkbox": "SkillCheckBox",
          "cardname": "SkillCardName",
        };
        skillInteraction.sourceComponent = Qt.createComponent(
          "LunarLtk.Components.SkillInteraction", pages[data.type]);
        const modelComponent = Qt.createComponent("LunarLtk.Models.Popups", "ChoicesModel");
        const model = modelComponent.createObject(null, {
          choices: data.choices,
          allChoices: data.all_choices,
          cancelable: data.cancelable ?? false,
          skillName: skill_name,
          detailed: data.detailed ?? false,
          result: data.default ? [data.default] : [],
          minNum: data.min_num ?? 1,
          maxNum: data.max_num ?? 1,
          single: data.type === "combo" || data.type == "cardname",
        });
        skillInteraction.item.dataModel = model;
        skillInteraction.item.clicked();
        break;
      case "optionbox":
        const [options, all_options, single, min_num, max_num, direct] = [data.options, data.all_options, data.single, data.min_num, data.max_num, data.direct_send];
        const optionComponent = Qt.createComponent("LunarLtk.Models", "OptionsModel");
        const optionModel = optionComponent.createObject(null, {
          options,
          allOptions: all_options,
          minNum: min_num,
          maxNum: max_num,
          cancelable: roomScene.dataModel.cancelEnabled,
          skillName: skill_name,
          prompt: "",
          single: direct || single,
          enableOK: !direct,
          acceptable: roomScene.dataModel.okEnabled
        });
        optionModel.update.connect(option => {
          Lua.updateRequestUI("Interaction", "1", "update", optionModel.single ? (optionModel.result[0] ?? "") : optionModel.result)
          });
        optionModel.accepted.connect(() => {
          if (direct) {
            Lua.updateRequestUI("Interaction", "1", "finish", optionModel.result[0] ?? "");
          }
          Lua.updateRequestUI("Button", "OK")
        });
        optionModel.rejected.connect(() => Lua.updateRequestUI("Button", "Cancel"));
        dataModel.options = optionModel;

        dataModel.optionVisible = true;
        break;
      case "spin":
        skillInteraction.sourceComponent =
          Qt.createComponent("LunarLtk.Components.SkillInteraction", "SkillSpin");
        skillInteraction.item.skill = skill_name;
        skillInteraction.item.from = data.from;
        skillInteraction.item.to = data.to;
        skillInteraction.item.value = data.default;
        skillInteraction.item?.clicked();
        break;
      case "expandItems": {
        skillInteraction.sourceComponent =
          Qt.createComponent("LunarLtk.Components.SkillInteraction", "SkillExpandItems");

        let specs = [];
        if (data.ids) {
          specs.push(...data.ids.map(cid => ({ type: "card", cid })));
        }
        if (data.card_names) {
          specs.push(...data.card_names.map(name => ({ type: "card", name })));
        }
        // TODO: others
        skillInteraction.item.specList = specs;
        skillInteraction.item.clicked();
        break;
      }
      case "custom":
        skillInteraction.sourceComponent = Lua.createComponent(data.qml);
        if (data.qml.model) {
          const model = Lua.createQmlObject(data.qml.model);
          if ("skillName" in model) {
            model.skillName = skill_name;
          }
          skillInteraction.item.model = model;
        }
        if (data.qml.prop) {
          Object.assign(skillInteraction.item, data.qml.prop);
        }
        skillInteraction.item?.clicked();
        break;
      default:
        skillInteraction.sourceComponent = undefined;
        break;
      }
    }

    if (uiUpdate["Interaction"]) handleInteractionRefresh(uiUpdate);
  }

  // interaction真神了，这么多函数伺候它一个
  function handleInteractionRefresh(uiUpdate) {
    // console.log("handleInteractionRefresh", JSON.stringify(uiUpdate["Interaction"]));
    for (const dat of (uiUpdate["Interaction"] || [])) {
    const [type, refresh_data] = [dat.spec?.type, dat.refresh_data]
      if (!type || !refresh_data) continue; 
    // 所有允许refresh_interaction的skillInteraction都要在这里把数据传到interaction里

    switch (type) {
      case "optionbox":
          const optionModel = roomScene.dataModel.options;
      if (optionModel) {
            const orig_options = optionModel.options;
            optionModel.enabledOptions = refresh_data.filter(str => orig_options.indexOf(str) !== -1);
          }
          break;
        case "ToBeDecided": {
          const handArea = Ltk.roomScene.dashboard.handcardArea;
          if (refresh_data.expandItems) {
            const expandItems = [];
            const cardComponent = Qt.createComponent("LunarLtk.Components", "CardItem");
            for (const spec of refresh_data.expandItems) {
              if (spec.prop.type === "card") {
                let dataModel;
                if (spec.prop.card) {
                  dataModel = Ltk.createCardModelFromLuaValue(spec.prop.card, spec.prop.additional_prop);
                } else if (spec.prop.cid) {
                  dataModel = Ltk.createCardModel(spec.prop.cid, spec.prop.additional_prop);
                }
                const item = cardComponent.createObject(Ltk.roomScene, { dataModel }) as CardItem;
                item.dataModel.miscExpandId = spec.cid;
                item.clicked.connect(cardSelf => {
                  if (cardSelf.selectable) {
                    Lua.updateRequestUI("Interaction", "1", "update", {
                      elemType: "ExpandItem",
                      cid: spec.cid,
                      name: spec.name
                    } );
                  }
                });
                expandItems.push(item);
              } else if (spec.prop.type === "general") {
                let dataModel = Ltk.createGeneralCardModel(spec.prop.name, spec.prop.additional_prop);
                const component = Qt.createComponent("LunarLtk.Components", "GeneralCardItem");
                const item = component.createObject(Ltk.roomScene, { dataModel }) as GeneralCardItem;
                item.dataModel.miscExpandId = spec.cid;
                item.clicked.connect(cardSelf => {
                  if (cardSelf.selectable) {
                    Lua.updateRequestUI("Interaction", "1", "update", {
                      elemType: "ExpandItem",
                      cid: spec.cid,
                      name: spec.name,
                    } );
                  }
                });
                expandItems.push(item);
              } else if (spec.qml) {
                // TODO
              }
            }
            handArea.addMiscExpand(expandItems);
          }
          if (refresh_data.enabled_ids || refresh_data.pendings) {
            handArea.updateMiscExpand(refresh_data.enabled_ids, refresh_data.pendings);
          }
          if (refresh_data.optionBox) {
            const [options, all_options, single, min_num, max_num, direct, cancelable] = [refresh_data.optionBox.options, refresh_data.optionBox.all_options, refresh_data.optionBox.single, refresh_data.optionBox.min_num, refresh_data.optionBox.max_num, refresh_data.optionBox.direct_send, refresh_data.optionBox.cancelable];
            const optionComponent = Qt.createComponent("LunarLtk.Models", "OptionsModel");
            const optionModel = optionComponent.createObject(null, {
              options,
              allOptions: all_options,
              minNum: 1,
              maxNum: 1,
              cancelable: cancelable || roomScene.dataModel.cancelEnabled,
              skillName: dat.skill_name,
              prompt: "",
              single: true,
              enableOK: false,
              acceptable: true,
            });
            optionModel.accepted.connect(() => {
              const option_answer = optionModel.result[0] ?? "";
              if (direct) {
                Lua.updateRequestUI("Interaction", "1", "finish", {
                  option: option_answer,
                });
                Lua.updateRequestUI("Button", "OK");
              } else {
                Lua.updateRequestUI("Interaction", "1", "update", {
                  elemType: "OptionBox",
                  option: option_answer,
                } );
              }
            });
            optionModel.rejected.connect(() => {
              if (cancelable) {
                Lua.updateRequestUI("Interaction", "1", "update", {
                  elemType: "OptionBox",
                  option: "Cancel"
                } );
              } else {
                Lua.updateRequestUI("Button", "Cancel")
              }
            });
            dataModel.options = optionModel;
            dataModel.optionVisible = true;
          } else {
            if (dataModel.options) {
              dataModel.options.destroy();
              dataModel.options = null;
            }
            dataModel.optionVisible = false;
          }
          break;
        }
      }
    }
  }

  function updateRequestUI(sender, uiUpdate) {
    if (uiUpdate["_prompt"])
      roomScene.dataModel.prompt = uiUpdate["_prompt"];

    if (uiUpdate._type == "Room") {
      roomScene.applyChange(uiUpdate);
    }
  }

  function getAreaItem(area, id) {
    if (area === Ltk.Card.DrawPile) {
      return drawPile;
    } else if (area === Ltk.Card.DiscardPile || area === Ltk.Card.Processing ||
             area === Ltk.Card.Void) {
      return tablePile;
    }

    const photo = getPhoto(id);
    if (!photo) {
      return null;
    }

    if (area === Ltk.Card.PlayerHand && id === Cpp.self.id) {
      return dashboard.handcardArea;
    }

    return photo.getAreaItem(area);
  }

  function moveCards(move, data) {
    const from = getAreaItem(move.fromArea, move.from);
    const to = getAreaItem(move.toArea, move.to);
    if (!from || !to) return;
    if (from === to && from !== tablePile) return;
    if (from === tablePile && move.toArea === Ltk.Card.DiscardPile) return;

    const items = from.remove(data, move.fromSpecialName);
    if (items.length > 0)
      to.add(items, move.specialName);
    to.updateCardPosition(true);
  }

  function showVirtualCard(sender, data) {
    const [card_data, playerid, footnote, event_id] = data;
    let from = drawPile;
    const photo = getPhoto(playerid);
    if (photo) {
      from = (playerid === Cpp.self.id ? dashboard.handcardArea : photo.getAreaItem(Ltk.Card.PlayerHand));
    }

    const items = [];
    for (let i = 0; i < card_data.length; i++) {
      const dat = Lua.toQml(card_data[i]);
      const card = Lua.createQmlObject(dat, roomScene.dynamicCardArea);
      const parentPos = roomScene.mapFromItem(from, from.width / 2, from.height / 2);
      card.x = parentPos.x - card.width / 2;
      card.y = parentPos.y - card.height / 2;
      // card.holding_event_id = event_id;
      card.known = true;
      if (footnote) {
        card.footnote = footnote;
        card.dataModel.footnoteVisible = true;
      }
      items.push(card);
    }

    tablePile.add(items);
    tablePile.updateCardPosition(true);
  }

  // TODO: 处理minigame，但现在懒得管
  /* function handleMiniGame(sender, data) {
    const game = data.type;
    const dat = data.data;
    const gdata = Ltk.getMiniGame(game, Cpp.self.id, JSON.stringify(dat));
    const component = Qt.createComponent(Cpp.path + "/" + gdata.qml_path + ".qml")
    console.log(component.status, component.errorString());
    dataModel.activate();
    showPopup(component);
    if (dat) {
      roomScene.popupItem.loadData(dat);
    }
  } */

  function updateMiniGame(sender, data) {
    roomScene.popupItem?.updateData(data);
  }

  function showDistance(show) {
    for (let i = 0; i < photoModel.count; i++) {
      const model = photoModel.get(i).modelData;
      if (show) {
        model.distance = Lua.selfPlayer.distanceTo(model.luaPlayer);
      } else {
        model.distance = -1;
      }
    }
  }

  function arrangeManyPhotos() {
    /* Layout of photos:
     * +----------------+
     * |    -2 ... 2    |
     * | -1           1 |
     * |              0 |
     * +----------------+
     */

    const playerNum = roomScene.dataModel.playerNum;
    const photoBaseWidth = 175 * 0.75;
    const photoMaxWidth = 175 * 0.75;
    // const verticalSpacing = 32;
    const verticalSpacing = roomArea.height * 0.08;
    // Padding is negative, because photos are scaled.
    const roomAreaPadding = 16;

    let horizontalSpacing = 8;
    let photoWidth = (roomArea.width - horizontalSpacing * playerNum)
                   / (playerNum - 1);
    let photoScale = 1;
    if (photoWidth > photoMaxWidth) {
      photoWidth = photoMaxWidth;
      horizontalSpacing = (roomArea.width - photoWidth * (playerNum - 1))
                        / playerNum;
    } else {
      photoScale = photoWidth / photoBaseWidth;
    }

    const horizontalPadding = (photoWidth - photoBaseWidth) / 2;
    const startX = horizontalPadding + horizontalSpacing;
    const padding = photoWidth + horizontalSpacing;
    let regions = [
      {
        x: startX + padding * (playerNum - 2),
        y: roomScene.height - 192,
        scale: photoScale
      },
    ];
    let i;
    for (i = 0; i < playerNum - 1; i++) {
      regions.push({
        x: startX + padding * (playerNum - 2 - i),
        y: roomAreaPadding,
        scale: photoScale,
      });
    }
    regions[1].y += verticalSpacing * 3;
    regions[regions.length - 1].y += verticalSpacing * 3;
    regions[2].y += verticalSpacing;
    regions[regions.length - 2].y += verticalSpacing;

    let item, region;

    for (i = 0; i < playerNum; i++) {
      item = photos.itemAt(i);
      if (!item)
        continue;

      region = regions[photoModel.get(i).modelData.index];
      item.x = region.x;
      item.y = region.y;
      item.scale = region.scale;
    }
  }

  function arrangePhotos() {
    const playerNum = roomScene.dataModel.playerNum;
    if (playerNum > 8) {
      return arrangeManyPhotos();
    }

    /* Layout of photos:
     * +---------------+
     * |   6 5 4 3 2   |
     * | 7           1 |
     * |             0 |
     * +---------------+
     */

    const photoWidth = 175 * 0.75;
    // Padding is negative, because photos are scaled.
    const roomAreaPadding = 16;
    const verticalPadding = 0;
    const verticalSpacing = roomArea.height * 0.08;
    const horizontalSpacing = (roomArea.width - photoWidth * 7) / 8;

    // Position 1-7
    const startX = verticalPadding + horizontalSpacing;
    const padding = photoWidth + horizontalSpacing;
    const regions = [
      { x: startX + padding * 6, y: roomScene.height - 192 },
      { x: startX + padding * 6, y: roomAreaPadding + verticalSpacing * 3 },
      { x: startX + padding * 5, y: roomAreaPadding + verticalSpacing },
      { x: startX + padding * 4, y: roomAreaPadding },
      { x: startX + padding * 3, y: roomAreaPadding },
      { x: startX + padding * 2, y: roomAreaPadding },
      { x: startX + padding, y: roomAreaPadding + verticalSpacing },
      { x: startX, y: roomAreaPadding + verticalSpacing * 3 },
    ];

    const regularSeatIndex = [
      [0],
      [0, 4],
      [0, 3, 5],
      [0, 1, 4, 7],
      [0, 1, 3, 5, 7],
      [0, 1, 3, 4, 5, 7],
      [0, 1, 2, 3, 5, 6, 7],
      [0, 1, 2, 3, 4, 5, 6, 7],
    ];
    const seatIndex = regularSeatIndex[playerNum - 1];

    let item, region, i;

    for (i = 0; i < playerNum; i++) {
      item = photos.itemAt(i);
      if (!item)
        continue;

      region = regions[seatIndex[photoModel.get(i).modelData.index]];
      item.x = region.x;
      item.y = region.y;
    }
  }

  function activateSkill(skill_name, selected, action) {
    let data;
    if (action === "click") data = { selected, autoTarget: Config.autoTarget };
    else if (action === "doubleClick") data = { selected, doubleClickUse: Config.doubleClickUse, autoTarget: Config.autoTarget };
    else data = { selected };
    Lua.updateRequestUI("SkillButton", skill_name, action, data);
  }

  function setupCallbacks() {
    dataModel.setupCallbacks();

    addCallback(Command.MoveFocus, moveFocus);
    addCallback(Command.Animate, doAnimate);
    addCallback(Command.LogEvent, logEvent);

    addCallback(Command.CloseAG, () => agItem.close());

    addCallback(Command.UpdateMiniGame, updateMiniGame);

    addCallback(Command.UpdateRequestUI, updateRequestUI);

    addCallback(Command.ShowVirtualCard, showVirtualCard);

    addCallback("Ltk.SkillInvoked", (_, data) => popupLogArea.show(data, 3000, 2));
  }

  Component.onCompleted: {
    initializeRoom()
  }
}
