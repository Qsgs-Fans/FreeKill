// SPDX-License-Identifier: GPL-3.0-or-later

const Card = {
  Unknown : 0,
  PlayerHand : 1,
  PlayerEquip : 2,
  PlayerJudge : 3,
  PlayerSpecial : 4,
  Processing : 5,
  DrawPile : 6,
  DiscardPile : 7,
  Void : 8
}

function arrangeManyPhotos() {
  /* Layout of photos:
   * +----------------+
   * |    -2 ... 2    |
   * | -1           1 |
   * |              0 |
   * +----------------+
   */

  const photoBaseWidth = 175;
  const photoMaxWidth = 175 * 0.75;
  const verticalSpacing = 32;
  // Padding is negative, because photos are scaled.
  const roomAreaPadding = -16;

  let horizontalSpacing = 8;
  let photoWidth = (roomArea.width - horizontalSpacing * playerNum) / (playerNum - 1);
  let photoScale = 0.75;
  if (photoWidth > photoMaxWidth) {
    photoWidth = photoMaxWidth;
    horizontalSpacing = (roomArea.width - photoWidth * (playerNum - 1)) / playerNum;
  } else {
    photoScale = photoWidth / photoBaseWidth;
  }

  const horizontalPadding = (photoWidth - photoBaseWidth) / 2;
  const startX = horizontalPadding + horizontalSpacing;
  const padding = photoWidth + horizontalSpacing;
  let regions = [
    {
      x: startX + padding * (playerNum - 2),
      y: roomScene.height - 220,
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

    region = regions[photoModel.get(i).index];
    item.x = region.x;
    item.y = region.y;
    item.scale = region.scale;
  }
}

function arrangePhotos() {
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
  const roomAreaPadding = -16;
  const verticalPadding = -175 / 8;
  const horizontalSpacing = 32;
  const verticalSpacing = (roomArea.width - photoWidth * 7) / 8;

  // Position 1-7
  const startX = verticalPadding + verticalSpacing;
  const padding = photoWidth + verticalSpacing;
  const regions = [
    { x: startX + padding * 6, y: roomScene.height - 220 },
    { x: startX + padding * 6, y: roomAreaPadding + horizontalSpacing * 3 },
    { x: startX + padding * 5, y: roomAreaPadding + horizontalSpacing },
    { x: startX + padding * 4, y: roomAreaPadding },
    { x: startX + padding * 3, y: roomAreaPadding },
    { x: startX + padding * 2, y: roomAreaPadding },
    { x: startX + padding, y: roomAreaPadding + horizontalSpacing },
    { x: startX, y: roomAreaPadding + horizontalSpacing * 3 },
  ];

  const regularSeatIndex = [
    [0, 4],
    [0, 3, 5],
    [0, 1, 4, 7],
    [0, 1, 3, 5, 7],
    [0, 1, 3, 4, 5, 7],
    [0, 1, 2, 3, 5, 6, 7],
    [0, 1, 2, 3, 4, 5, 6, 7],
  ];
  const seatIndex = regularSeatIndex[playerNum - 2];

  let item, region, i;

  for (i = 0; i < playerNum; i++) {
    item = photos.itemAt(i);
    if (!item)
      continue;

    region = regions[seatIndex[photoModel.get(i).index]];
    item.x = region.x;
    item.y = region.y;
  }
}

function doOkButton() {
  if (roomScene.state === "playing" || roomScene.state === "responding") {
    const reply = JSON.stringify(
      {
        card: dashboard.getSelectedCard(),
        targets: selected_targets,
        special_skill: roomScene.getCurrentCardUseMethod(),
        interaction_data: roomScene.skillInteraction.item ? roomScene.skillInteraction.item.answer : undefined,
      }
    );
    replyToServer(reply);
    return;
  }
  if (roomScene.extra_data.luckCard) {
    okButton.enabled = false;
    ClientInstance.notifyServer("PushRequest", [
      "luckcard", true
    ].join(","));

    if (roomScene.extra_data.time === 1) {
      roomScene.state = "notactive";
    }

    return;
  }
  replyToServer("1");
}

let _is_canceling = false;
function doCancelButton() {
  if (_is_canceling) return;
  _is_canceling = true;

  if (roomScene.state === "playing") {
    dashboard.stopPending();
    dashboard.deactivateSkillButton();
    dashboard.unSelectAll();
    dashboard.enableCards();
    dashboard.enableSkills();

    _is_canceling = false;
    return;
  } else if (roomScene.state === "responding") {
    const p = dashboard.pending_skill;
    dashboard.stopPending();
    dashboard.deactivateSkillButton();
    dashboard.unSelectAll();
    if (roomScene.autoPending || !p) {
      replyToServer("__cancel");
    } else {
      dashboard.enableCards(roomScene.responding_card);
      dashboard.enableSkills(roomScene.responding_card);
    }

    _is_canceling = false;
    return;
  }

  if (roomScene.extra_data.luckCard) {
    ClientInstance.notifyServer("PushRequest", [
      "luckcard", false
    ].join(","));
    roomScene.state = "notactive";

    _is_canceling = false;
    return;
  }

  replyToServer("__cancel");
  _is_canceling = false;
}

function replyToServer(jsonData) {
  ClientInstance.replyToServer("", jsonData);
  if (!mainWindow.is_pending) {
    roomScene.state = "notactive";
  } else {
    roomScene.state = "";
    const data = mainWindow.fetchMessage();
    return mainWindow.handleMessage(data.command, data.jsonData);
  }
}

function getPhotoModel(id) {
  for (let i = 0; i < photoModel.count; i++) {
    const item = photoModel.get(i);
    if (item.id === id) {
      return item;
    }
  }
  return undefined;
}

function getPhoto(id) {
  for (let i = 0; i < photoModel.count; i++) {
    const item = photoModel.get(i);
    if (item.id === id) {
      return photos.itemAt(i);
    }
  }
  return undefined;
}

function getPhotoOrDashboard(id) {
  if (id === Self.id)
    return dashboard;
  return getPhoto(id);
}

function getAreaItem(area, id) {
  if (area === Card.DrawPile) {
    return drawPile;
  } else if (area === Card.DiscardPile || area === Card.Processing || area === Card.Void) {
    return tablePile;
  } else if (area === Card.AG) {
    return popupBox.item;
  }

  const photo = getPhoto(id);
  if (!photo) {
    return null;
  }

  if (area === Card.PlayerHand) {
    return id === Self.id ? dashboard.handcardArea : photo.handcardArea;
  } else if (area === Card.PlayerEquip) {
    return photo.equipArea;
  } else if (area === Card.PlayerJudge) {
    return photo.delayedTrickArea;
  } else if (area === Card.PlayerSpecial) {
    return photo.specialArea;
  }

  return null;
}

function moveCards(moves) {
  for (let i = 0; i < moves.length; i++) {
    const move = moves[i];
    const from = getAreaItem(move.fromArea, move.from);
    const to = getAreaItem(move.toArea, move.to);
    if (!from || !to || from === to)
      continue;
    const items = from.remove(move.ids, move.fromSpecialName);
    if (items.length > 0)
      to.add(items, move.specialName);
    to.updateCardPosition(true);
  }
}

function resortHandcards() {
  if (!dashboard.handcardArea.cards.length) {
    return;
  }

  const subtypeString2Number = {
    ["none"]: Card.SubtypeNone,
    ["delayed_trick"]: Card.SubtypeDelayedTrick,
    ["weapon"]: Card.SubtypeWeapon,
    ["armor"]: Card.SubtypeArmor,
    ["defensive_horse"]: Card.SubtypeDefensiveRide,
    ["offensive_horse"]: Card.SubtypeOffensiveRide,
    ["treasure"]: Card.SubtypeTreasure,
  }

  dashboard.handcardArea.cards.sort((prev, next) => {
    if (prev.type === next.type) {
      const prevSubtypeNumber = subtypeString2Number[prev.subtype];
      const nextSubtypeNumber = subtypeString2Number[next.subtype];
      if (prevSubtypeNumber === nextSubtypeNumber) {
        const splitedPrevName = prev.name.split('__');
        const prevTrueName = splitedPrevName[splitedPrevName.length - 1];

        const splitedNextName = next.name.split('__');
        const nextTrueName = splitedNextName[splitedNextName.length - 1];
        if (prevTrueName === nextTrueName) {
          return prev.cid - next.cid;
        } else {
          return prevTrueName > nextTrueName ? -1 : 1;
        }
      } else {
        return prevSubtypeNumber - nextSubtypeNumber;
      }
    } else {
      return prev.type - next.type;
    }
  });

  dashboard.handcardArea.updateCardPosition(true);
}

function setEmotion(id, emotion, isCardId) {
  let path;
  if (OS === "Win") {
    // Windows: file:///C:/xxx/xxxx
    path = (SkinBank.PIXANIM_DIR + emotion).replace("file:///", "");
  } else {
    path = (SkinBank.PIXANIM_DIR + emotion).replace("file://", "");
  }

  if (!Backend.exists(path)) {
    // Try absolute path again
    if (OS === "Win") {
      // Windows: file:///C:/xxx/xxxx
      path = (AppPath + "/" + emotion).replace("file:///", "");
    } else {
      path = (AppPath + "/" + emotion).replace("file://", "");
    }
    if (!Backend.exists(path))
      return;
  }
  if (!Backend.isDir(path)) {
    // TODO: set picture emotion
    return;
  }
  const component = Qt.createComponent("../RoomElement/PixmapAnimation.qml");
  if (component.status !== Component.Ready)
    return;

  let photo;
  if (isCardId === true) {
    roomScene.tableCards.forEach((v) => {
      if (v.cid === id) {
        photo = v;
        return;
      }
    })
    if (!photo)
      return;
  } else {
    photo = getPhoto(id);
    if (!photo) {
      return null;
    }
  }

  const animation = component.createObject(photo, {source: (OS === "Win" ? "file:///" : "") + path});
  animation.anchors.centerIn = photo;
  if (isCardId) {
    animation.started.connect(() => photo.busy = true);
    animation.finished.connect(() => {
      photo.busy = false;
      animation.destroy()
    });
  } else {
    animation.finished.connect(() => animation.destroy());
  }
  animation.start();
}

function setCardFootnote(id, footnote) {
  let card;
  roomScene.tableCards.forEach((v) => {
    if (v.cid === id) {
      card = v;
      return;
    }
  });

  if (!card) {
    return;
  }

  card.footnote = footnote;
  card.footnoteVisible = true;
}

callbacks["SetCardFootnote"] = (j) => {
  const data = JSON.parse(j);
  const id = data[0];
  const note = data[1];
  setCardFootnote(id, note);
}

function setCardVirtName(id, name) {
  let card;
  roomScene.tableCards.forEach((v) => {
    if (v.cid === id) {
      card = v;
      return;
    }
  });

  if (!card) {
    return;
  }

  card.virt_name = name;
}

callbacks["SetCardVirtName"] = (j) => {
  const data = JSON.parse(j);
  const ids = data[0];
  const note = data[1];
  ids.forEach(id => setCardVirtName(id, note));
}

function changeHp(id, delta, losthp) {
  const photo = getPhoto(id);
  if (!photo) {
    return null;
  }
  if (delta < 0) {
    if (!losthp) {
      setEmotion(id, "damage")
      photo.tremble()
    }
  }
}

function doIndicate(from, tos) {
  const component = Qt.createComponent("../RoomElement/IndicatorLine.qml");
  if (component.status !== Component.Ready)
    return;

  const fromItem = getPhotoOrDashboard(from);
  const fromPos = mapFromItem(fromItem, fromItem.width / 2, fromItem.height / 2);

  const end = [];
  for (let i = 0; i < tos.length; i++) {
    if (from === tos[i])
      continue;
    const toItem = getPhotoOrDashboard(tos[i]);
    const toPos = mapFromItem(toItem, toItem.width / 2, toItem.height / 2);
    end.push(toPos);
  }

  const color = "#96943D";
  const line = component.createObject(roomScene, {start: fromPos, end: end, color: color});
  line.finished.connect(() => line.destroy());
  line.running = true;
}

callbacks["MaxCard"] = (jsonData) => {
  const data = JSON.parse(jsonData);
  const id = data.id;
  const cardMax = data.pcardMax;
  const photo = getPhoto(id);
  if (photo) {
    photo.maxCard = cardMax;
  }
}

function changeSelf(id) {
  Backend.callLuaFunction("ChangeSelf", [id]);

  // move new selfPhoto to dashboard
  let order = new Array(photoModel.count);
  for (let i = 0; i < photoModel.count; i++) {
    const item = photoModel.get(i);
    order[item.seatNumber - 1] = item.id;
    if (item.id === Self.id) {
      dashboard.self = photos.itemAt(i);
    }
  }
  callbacks["ArrangeSeats"](JSON.stringify(order));

  // update dashboard
  dashboard.update();

  // handle pending messages
  if (mainWindow.is_pending) {
    const data = mainWindow.fetchMessage();
    return mainWindow.handleMessage(data.command, data.jsonData);
  }
}

callbacks["AddPlayer"] = (jsonData) => {
  // jsonData: int id, string screenName, string avatar, bool ready
  for (let i = 0; i < photoModel.count; i++) {
    const item = photoModel.get(i);
    if (item.id === -1) {
      const data = JSON.parse(jsonData);
      const uid = data[0];
      const name = data[1];
      const avatar = data[2];
      const ready = data[3];

      item.id = uid;
      item.screenName = name;
      item.general = avatar;
      item.avatar = avatar;
      item.ready = ready;

      checkAllReady();

      if (getPhoto(-1)) {
        roomScene.isFull = false;
      } else {
        roomScene.isFull = true;
      }

      return;
    }
  }
}

function enableTargets(card) { // card: int | { skill: string, subcards: int[] }
  if (roomScene.respond_play) {
    const candidate = (!isNaN(card) && card !== -1) || typeof(card) === "string";
    if (candidate) {
      okButton.enabled = JSON.parse(Backend.callLuaFunction(
        "CardFitPattern",
        [card, roomScene.responding_card]
      )) && !JSON.parse(Backend.callLuaFunction(
        "CardProhibitedResponse", [card]));
    } else {
      okButton.enabled = false;
    }
    return;
  }

  let i = 0;
  const candidate = (!isNaN(card) && card !== -1) || typeof(card) === "string";
  const all_photos = [];
  for (i = 0; i < playerNum; i++) {
    all_photos.push(photos.itemAt(i))
  }
  selected_targets = [];
  for (i = 0; i < playerNum; i++) {
    all_photos[i].selected = false;
  }

  if (candidate) {
    const data = {
      ok_enabled: false,
      enabled_targets: []
    }

    all_photos.forEach(photo => {
      photo.state = "candidate";
      const id = photo.playerid;
      const ret = JSON.parse(Backend.callLuaFunction(
        "CanUseCardToTarget",
        [card, id, selected_targets]
      ));
      photo.selectable = ret;
      if (roomScene.extra_data instanceof Object) {
        const exclusived = roomScene.extra_data.exclusive_targets;
        if (exclusived instanceof Array) {
          if (exclusived.indexOf(id) === -1) photo.selectable = false;
        }
      }
    })

    okButton.enabled = JSON.parse(Backend.callLuaFunction(
      "CardFeasible", [card, selected_targets]
    ));
    if (okButton.enabled && roomScene.state === "responding") {
      okButton.enabled = JSON.parse(Backend.callLuaFunction(
        "CardFitPattern",
        [card, roomScene.responding_card]
      )) && (roomScene.autoPending || !JSON.parse(Backend.callLuaFunction(
        "CardProhibitedUse", [card])));
    } else if (okButton.enabled && roomScene.state === "playing") {
      okButton.enabled = JSON.parse(Backend.callLuaFunction("CanUseCard", [card, Self.id]));
    }
    if (okButton.enabled) {
      if (roomScene.extra_data instanceof Object) {
        const must = roomScene.extra_data.must_targets;
        if (must instanceof Array) {
          okButton.enabled = (must.length === 0);
        }
      }
    }
  } else {
    all_photos.forEach(photo => {
      photo.state = "normal";
      photo.selected = false;
    });

    okButton.enabled = false;
  }
}

function updateSelectedTargets(playerid, selected) {
  let i = 0;
  const card = dashboard.getSelectedCard();
  const candidate = (!isNaN(card) && card !== -1) || typeof(card) === "string";
  const all_photos = [];
  for (i = 0; i < playerNum; i++) {
    all_photos.push(photos.itemAt(i))
  }

  if (selected) {
    selected_targets.push(playerid);
  } else {
    selected_targets.splice(selected_targets.indexOf(playerid), 1);
  }

  if (candidate) {
    all_photos.forEach(photo => {
      if (photo.selected) return;
      const id = photo.playerid;
      const ret = JSON.parse(Backend.callLuaFunction(
        "CanUseCardToTarget",
        [card, id, selected_targets]
      ));
      photo.selectable = ret;
      if (roomScene.extra_data instanceof Object) {
        const exclusived = roomScene.extra_data.exclusive_targets;
        if (exclusived instanceof Array) {
          if (exclusived.indexOf(id) === -1) photo.selectable = false;
        }
      }
    })

    okButton.enabled = JSON.parse(Backend.callLuaFunction(
      "CardFeasible", [card, selected_targets]
    ));
    if (okButton.enabled && roomScene.state === "responding") {
      okButton.enabled = JSON.parse(Backend.callLuaFunction(
        "CardFitPattern",
        [card, roomScene.responding_card]
      )) && (roomScene.autoPending || !JSON.parse(Backend.callLuaFunction(
        "CardProhibitedUse", [card])));
    } else if (okButton.enabled && roomScene.state === "playing") {
      okButton.enabled = JSON.parse(Backend.callLuaFunction("CanUseCard", [card, Self.id]));
    }
    if (okButton.enabled) {
      if (roomScene.extra_data instanceof Object) {
        const must = roomScene.extra_data.must_targets;
        if (must instanceof Array) {
          okButton.enabled = (must.filter((val) => {
            return selected_targets.indexOf(val) === -1;
          }).length === 0);
        }
      }
    }
  } else {
    all_photos.forEach(photo => {
      photo.state = "normal";
      photo.selected = false;
    });

    okButton.enabled = false;
  }
}

callbacks["RemovePlayer"] = (jsonData) => {
  // jsonData: int uid
  const uid = JSON.parse(jsonData)[0];
  const model = getPhotoModel(uid);
  if (typeof(model) !== "undefined") {
    model.id = -1;
    model.screenName = "";
    model.general = "";
    model.isOwner = false;
    roomScene.isFull = false;
  }
}

callbacks["RoomOwner"] = (jsonData) => {
  // jsonData: int uid of the owner
  const uid = JSON.parse(jsonData)[0];

  roomScene.isOwner = (Self.id === uid);

  const model = getPhotoModel(uid);
  if (typeof(model) !== "undefined") {
    model.isOwner = true;
  }
}

function checkAllReady() {
  let allReady = true;
  for (let i = 0; i < photoModel.count; i++) {
    const item = photoModel.get(i);
    if (!item.isOwner && !item.ready) {
      allReady = false;
      break;
    }
  }
  roomScene.isAllReady = allReady;
}

callbacks["ReadyChanged"] = (j) => {
  const data = JSON.parse(j);
  const id = data[0];
  const ready = data[1];

  if (id === Self.id) {
    roomScene.isReady = ready === 1;
  }

  const model = getPhotoModel(id);
  if (typeof(model) !== "undefined") {
    model.ready = ready ? true : false;
    checkAllReady();
  }
}

callbacks["NetStateChanged"] = (j) => {
  const data = JSON.parse(j);
  const id = data[0];
  let state = data[1];

  const model = getPhotoModel(id);
  if (state === "run" && model.dead) {
    state = "leave";
  }
  model.netstate = state;
}

callbacks["PropertyUpdate"] = (jsonData) => {
  // jsonData: int id, string property_name, value
  const data = JSON.parse(jsonData);
  const uid = data[0];
  const property_name = data[1];
  let value = data[2];

  let model = getPhotoModel(uid);

  if (typeof(model) !== "undefined") {
    if (property_name == "sealedSlots")
      value = JSON.stringify(value); // 辣鸡qml

    model[property_name] = value;
  }

  if (property_name === "phase") {
    let item = getPhoto(uid);
    item.playing = value < 8; // Player.NotActive
  }
}

callbacks["UpdateCard"] = (j) => {
  const id = parseInt(j);
  let card;
  roomScene.tableCards.forEach((v) => {
    if (v.cid === id) {
      card = v;
      return;
    }
  });

  if (!card) {
    roomScene.dashboard.handcardArea.cards.forEach((v) => {
      if (v.cid === id) {
        card = v;
        return;
      }
    });
  }

  if (!card) {
    return;
  }

  const data = JSON.parse(Backend.callLuaFunction("GetCardData", [id]));
  card.setData(data);
}

callbacks["StartGame"] = (jsonData) => {
  roomScene.isStarted = true;

  for (let i = 0; i < photoModel.count; i++) {
    const item = photoModel.get(i);
    item.ready = false;
    item.general = "";
  }
}

callbacks["ArrangeSeats"] = (jsonData) => {
  // jsonData: seat order
  const order = JSON.parse(jsonData);

  for (let i = 0; i < photoModel.count; i++) {
    const item = photoModel.get(i);
    item.seatNumber = order.indexOf(item.id) + 1;
  }

  // make Self to the first of list, then reorder photomodel
  const selfIndex = order.indexOf(Self.id);
  const after = order.splice(selfIndex);
  after.push(...order);
  const photoOrder = after;

  for (let i = 0; i < photoModel.count; i++) {
    const item = photoModel.get(i);
    item.index = photoOrder.indexOf(item.id);
  }

  arrangePhotos();
}

function cancelAllFocus() {
  let item;
  for (let i = 0; i < playerNum; i++) {
    item = photos.itemAt(i);
    item.progressBar.visible = false;
    item.progressTip = "";
  }
}

callbacks["MoveFocus"] = (jsonData) => {
  // jsonData: int[] focuses, string command
  cancelAllFocus();
  const data = JSON.parse(jsonData);
  const focuses = data[0];
  const command = data[1];

  let item, model;
  for (let i = 0; i < playerNum; i++) {
    model = photoModel.get(i);
    if (focuses.indexOf(model.id) != -1) {
      item = photos.itemAt(i);
      item.progressBar.visible = true;
      item.progressTip = Backend.translate(command)
        + Backend.translate(" thinking...");

      /*
      if (command === "PlayCard") {
        item.playing = true;
      }
    } else {
      item = photos.itemAt(i);
      if (command === "PlayCard") {
        item.playing = false;
      }
    */
    }
  }
}

callbacks["PlayerRunned"] = (jsonData) => {
  // jsonData: int runner, int robot
  const data = JSON.parse(jsonData);
  const runner = data[0];
  const robot = data[1];

  const model = getPhotoModel(runner);
  if (typeof(model) !== "undefined") {
    model.id = robot;
  }
}

callbacks["AskForGeneral"] = (jsonData) => {
  // jsonData: string[] Generals
  const data = JSON.parse(jsonData);
  const generals = data[0];
  const n = data[1];
  const convert = data[2];
  const heg = data[3];
  roomScene.setPrompt(Backend.translate("#AskForGeneral"), true);
  roomScene.state = "replying";
  roomScene.popupBox.sourceComponent = Qt.createComponent("../RoomElement/ChooseGeneralBox.qml");
  const box = roomScene.popupBox.item;
  box.accepted.connect(() => {
    replyToServer(JSON.stringify(box.choices));
  });
  box.choiceNum = n;
  box.convertDisabled = !!convert;
  box.needSameKingdom = !!heg;
  for (let i = 0; i < generals.length; i++)
    box.generalList.append({ "name": generals[i] });
  box.updatePosition();
}

callbacks["AskForSkillInvoke"] = (jsonData) => {
  // jsonData: [ string name, string prompt ]
  const data = JSON.parse(jsonData);
  const skill = data[0];
  const prompt = data[1];
  roomScene.promptText = prompt ? processPrompt(prompt) : Backend.translate("#AskForSkillInvoke")
    .arg(Backend.translate(skill));
  roomScene.state = "replying";
  roomScene.okCancel.visible = true;
  roomScene.okButton.enabled = true;
  roomScene.cancelButton.enabled = true;
}

callbacks["AskForGuanxing"] = (jsonData) => {
  const data = JSON.parse(jsonData);
  const cards = [];
  const min_top_cards = data.min_top_cards;
  const max_top_cards = data.max_top_cards;
  const min_bottom_cards = data.min_bottom_cards;
  const max_bottom_cards = data.max_bottom_cards;
  const top_area_name = data.top_area_name;
  const bottom_area_name = data.bottom_area_name;
  const prompt = data.prompt;
  roomScene.state = "replying";
  roomScene.popupBox.sourceComponent = Qt.createComponent("../RoomElement/GuanxingBox.qml");
  data.cards.forEach(id => {
    const d = Backend.callLuaFunction("GetCardData", [id]);
    cards.push(JSON.parse(d));
  });
  const box = roomScene.popupBox.item;
  box.prompt = prompt;
  if (max_top_cards === 0) {
    box.areaCapacities = [max_bottom_cards];
    box.areaLimits = [min_bottom_cards];
    box.areaNames = [Backend.translate(bottom_area_name)];
  } else {
    if (max_bottom_cards === 0) {
      box.areaCapacities = [max_top_cards];
      box.areaLimits = [min_top_cards];
      box.areaNames = [Backend.translate(top_area_name)];
    } else {
      box.areaCapacities = [max_top_cards, max_bottom_cards];
      box.areaLimits = [min_top_cards, min_bottom_cards];
      box.areaNames = [Backend.translate(top_area_name), Backend.translate(bottom_area_name)];
    }
  }
  box.cards = cards;
  box.arrangeCards();
  box.accepted.connect(() => {
    replyToServer(JSON.stringify(box.getResult()));
  });
}

callbacks["AskForExchange"] = (jsonData) => {
  const data = JSON.parse(jsonData);
  const cards = [];
  const cards_name = [];
  const capacities = [];
  const limits = [];
  roomScene.state = "replying";
  roomScene.popupBox.sourceComponent = Qt.createComponent("../RoomElement/GuanxingBox.qml");
  let for_i = 0;
  const box = roomScene.popupBox.item;
  data.piles.forEach(ids => {
    if (ids.length > 0) {
      ids.forEach(id => {
        const d = Backend.callLuaFunction("GetCardData", [id]);
        cards.push(JSON.parse(d));
      });
      capacities.push(ids.length);
      limits.push(0);
      cards_name.push(Backend.translate(data.piles_name[for_i]));
      for_i ++;
    }
  });
  box.areaCapacities = capacities
  box.areaLimits = limits
  box.areaNames = cards_name
  box.cards = cards;
  box.arrangeCards();
  box.accepted.connect(() => {
    replyToServer(JSON.stringify(box.getResult()));
  });
}

callbacks["AskForChoice"] = (jsonData) => {
  // jsonData: [ string[] choices, string skill ]
  // TODO: multiple choices, e.g. benxi_ol
  const data = JSON.parse(jsonData);
  const choices = data[0];
  const all_choices = data[1];
  const skill_name = data[2];
  const prompt = data[3];
  const detailed = data[4];
  if (prompt === "") {
    roomScene.promptText = Backend.translate("#AskForChoice")
      .arg(Backend.translate(skill_name));
  } else {
    roomScene.setPrompt(processPrompt(prompt), true);
  }
  roomScene.state = "replying";
  let qmlSrc;
  if (!detailed) {
    qmlSrc = "../RoomElement/ChoiceBox.qml";
  } else {
    qmlSrc = "../RoomElement/DetailedChoiceBox.qml";
  }
  roomScene.popupBox.sourceComponent = Qt.createComponent(qmlSrc);
  const box = roomScene.popupBox.item;
  box.options = choices;
  box.skill_name = skill_name;
  box.all_options = all_choices;
  box.accepted.connect(() => {
    replyToServer(all_choices[box.result]);
  });
}

callbacks["AskForCardChosen"] = (jsonData) => {
  // jsonData: [ int[] handcards, int[] equips, int[] delayedtricks,
  //  string reason ]
  const data = JSON.parse(jsonData);
  const reason = data._reason;

  roomScene.promptText = Backend.translate("#AskForChooseCard")
    .arg(Backend.translate(reason));
  roomScene.state = "replying";
  roomScene.popupBox.sourceComponent = Qt.createComponent("../RoomElement/PlayerCardBox.qml");

  const box = roomScene.popupBox.item;
  for (let d of data.card_data) {
    const arr = [];
    const ids = d[1];

    ids.forEach(id => {
      const card_data = JSON.parse(Backend.callLuaFunction("GetCardData", [id]));
      arr.push(card_data);
    });
    box.addCustomCards(d[0], arr);
  }

  roomScene.popupBox.moveToCenter();
  box.cardSelected.connect(function(cid){
    replyToServer(cid);
  });
}

callbacks["AskForCardsChosen"] = (jsonData) => {
  // jsonData: [ int[] handcards, int[] equips, int[] delayedtricks,
  //  int min, int max, string reason ]
  const data = JSON.parse(jsonData);
  const min = data._min;
  const max = data._max;
  const reason = data._reason;

  roomScene.promptText = Backend.translate("#AskForChooseCards")
    .arg(Backend.translate(reason)).arg(min).arg(max);
  roomScene.state = "replying";
  roomScene.popupBox.sourceComponent = Qt.createComponent("../RoomElement/PlayerCardBox.qml");
  const box = roomScene.popupBox.item;
  box.multiChoose = true;
  box.min = min;
  box.max = max;
  for (let d of data.card_data) {
    const arr = [];
    const ids = d[1];

    ids.forEach(id => {
      const card_data = JSON.parse(Backend.callLuaFunction("GetCardData", [id]));
      arr.push(card_data);
    });
    box.addCustomCards(d[0], arr);
  }

  roomScene.popupBox.moveToCenter();
  box.cardsSelected.connect((ids) => {
    replyToServer(JSON.stringify(ids));
  });
}

callbacks["AskForMoveCardInBoard"] = (jsonData) => {
  const data = JSON.parse(jsonData);
  const { cards, cardsPosition, generalNames, playerIds } = data;

  roomScene.state = "replying";
  roomScene.popupBox.sourceComponent = Qt.createComponent("../RoomElement/MoveCardInBoardBox.qml");

  const boxCards = [];
  cards.forEach(id => {
    const cardPos = cardsPosition[cards.findIndex(cid => cid === id)];
    const d = Backend.callLuaFunction("GetCardData", [id, playerIds[cardPos]]);
    boxCards.push(JSON.parse(d));
  });

  const box = roomScene.popupBox.item;
  box.cards = boxCards;
  box.cardsPosition = cardsPosition;
  box.playerIds = playerIds;
  box.generalNames = generalNames.map(name => {
    const namesSplited = name.split('/');
    return namesSplited.length > 1 ? namesSplited.map(nameSplited => Backend.translate(nameSplited)).join('/') : Backend.translate(name)
  });

  box.arrangeCards();
  box.accepted.connect(() => {
    replyToServer(JSON.stringify(box.getResult()));
  });
}

callbacks["MoveCards"] = (jsonData) => {
  // jsonData: merged moves
  const moves = JSON.parse(jsonData);
  moveCards(moves);
}

callbacks["PlayCard"] = (jsonData) => {
  // jsonData: int playerId
  const playerId = parseInt(jsonData);
  if (playerId === Self.id) {
    roomScene.setPrompt(Backend.translate("#PlayCard"), true);
    roomScene.state = "playing";
    okButton.enabled = false;
  }
}

callbacks["LoseSkill"] = (jsonData) => {
  // jsonData: [ int player_id, string skill_name ]
  const data = JSON.parse(jsonData);
  const id = data[0];
  const skill_name = data[1];
  const prelight = data[2];
  if (id === Self.id) {
    dashboard.loseSkill(skill_name, prelight);
  }
}

callbacks["AddSkill"] = (jsonData) => {
  // jsonData: [ int player_id, string skill_name ]
  const data = JSON.parse(jsonData);
  const id = data[0];
  const skill_name = data[1];
  const prelight = data[2];
  if (id === Self.id) {
    dashboard.addSkill(skill_name, prelight);
  }
}

callbacks["PrelightSkill"] = (jsonData) => {
  const data = JSON.parse(jsonData);
  const skill_name = data[0];
  const prelight = data[1];

  dashboard.prelightSkill(skill_name, prelight);
}

// prompt: 'string:<src>:<dest>:<arg>:<arg2>'
function processPrompt(prompt) {
  const data = prompt.split(":");
  let raw = Backend.translate(data[0]);
  const src = parseInt(data[1]);
  const dest = parseInt(data[2]);
  if (raw.match("%src")) raw = raw.replace(/%src/g, Backend.translate(getPhoto(src).general));
  if (raw.match("%dest")) raw = raw.replace(/%dest/g, Backend.translate(getPhoto(dest).general));
  if (raw.match("%arg2")) raw = raw.replace(/%arg2/g, Backend.translate(data[4]));
  if (raw.match("%arg")) raw = raw.replace(/%arg/g, Backend.translate(data[3]));
  return raw;
}

callbacks["AskForUseActiveSkill"] = (jsonData) => {
  // jsonData: string skill_name, string prompt
  const data = JSON.parse(jsonData);
  const skill_name = data[0];
  const prompt = data[1];
  const cancelable = data[2];
  const extra_data = data[3] ?? {};
  if (prompt === "") {
    roomScene.promptText = Backend.translate("#AskForUseActiveSkill")
      .arg(Backend.translate(skill_name));
  } else {
    roomScene.setPrompt(processPrompt(prompt), true);
  }

  roomScene.respond_play = false;
  roomScene.state = "responding";

  if (JSON.parse(Backend.callLuaFunction('GetSkillData', [skill_name])).isViewAsSkill) {
    roomScene.responding_card = ".";
  }

  roomScene.autoPending = true;
  roomScene.extra_data = extra_data;
  // dashboard.startPending(skill_name);
  roomScene.activateSkill(skill_name, true);
  cancelButton.enabled = cancelable;
}

callbacks["CancelRequest"] = () => {
  roomScene.state = "notactive";
}

callbacks["GameLog"] = (jsonData) => {
  roomScene.addToLog(jsonData)
}

callbacks["AskForUseCard"] = (jsonData) => {
  // jsonData: card, pattern, prompt, cancelable, {}
  const data = JSON.parse(jsonData);
  const cardname = data[0];
  const pattern = data[1];
  const prompt = data[2];
  const extra_data = data[4];
  if (extra_data != null) {
    if (extra_data.effectTo !== Self.id && roomScene.skippedUseEventId.find(id => id === extra_data.useEventId)) {
      doCancelButton();
      return;
    } else {
      roomScene.extra_data = extra_data;
    }
  }

  if (prompt === "") {
    roomScene.promptText = Backend.translate("#AskForUseCard")
      .arg(Backend.translate(cardname));
  } else {
    roomScene.setPrompt(processPrompt(prompt), true);
  }
  roomScene.responding_card = pattern;
  roomScene.respond_play = false;
  roomScene.state = "responding";
  okButton.enabled = false;
  cancelButton.enabled = true;
}

callbacks["AskForResponseCard"] = (jsonData) => {
  // jsonData: card_name, pattern, prompt, cancelable, {}
  const data = JSON.parse(jsonData);
  const cardname = data[0];
  const pattern = data[1];
  const prompt = data[2];

  if (prompt === "") {
    roomScene.promptText = Backend.translate("#AskForResponseCard")
      .arg(Backend.translate(cardname));
  } else {
    roomScene.setPrompt(processPrompt(prompt), true);
  }
  roomScene.responding_card = pattern;
  roomScene.respond_play = true;
  roomScene.state = "responding";
  okButton.enabled = false;
  cancelButton.enabled = true;
}

callbacks["WaitForNullification"] = () => {
  roomScene.state = "notactive";
}

callbacks["SetPlayerMark"] = (jsonData) => {
  const data = JSON.parse(jsonData);
  const player = getPhoto(data[0]);
  const mark = data[1];
  const value = data[2] instanceof Array ? data[2] : data[2].toString();
  let area = mark.startsWith("@!") ? player.picMarkArea : player.markArea;
  if (data[2] === 0) {
    area.removeMark(mark);
  } else {
    area.setMark(mark, mark.startsWith("@@") ? "" : value);
  }
}

callbacks["Animate"] = (jsonData) => {
  // jsonData: [Object object]
  const data = JSON.parse(jsonData);
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
      setEmotion(data.player, data.emotion, data.is_card);
      break;
    case "LightBox":
      break;
    case "SuperLightBox": {
      const path = data.path;
      const jsonData = data.data;
      roomScene.bigAnim.source = AppPath + "/" + path;
      if (jsonData && jsonData !== "") {
        roomScene.bigAnim.item.loadData(jsonData);
      }
      break;
    }
    case "InvokeSkill": {
      const id = data.player;
      const component = Qt.createComponent("../RoomElement/SkillInvokeAnimation.qml");
      if (component.status !== Component.Ready)
        return;

      const photo = getPhoto(id);
      if (!photo) {
        return null;
      }

      const animation = component.createObject(photo, {
        skill_name: Backend.translate(data.name),
        skill_type: (data.skill_type ? data.skill_type : "special"),
      });
      animation.anchors.centerIn = photo;
      animation.finished.connect(() => animation.destroy());
      break;
    }
    case "InvokeUltSkill": {
      const id = data.player;
      const photo = getPhoto(id);
      if (!photo) {
        return null;
      }

      roomScene.bigAnim.source = "../RoomElement/UltSkillAnimation.qml";
      roomScene.bigAnim.item.loadData({
        skill_name: data.name,
        general: photo.general,
      });
      break;
    }
    default:
      break;
  }
}

callbacks["LogEvent"] = (jsonData) => {
  // jsonData: [Object object]
  const data = JSON.parse(jsonData);
  switch (data.type) {
    case "Damage": {
      const item = getPhotoOrDashboard(data.to);
      setEmotion(data.to, "damage");
      item.tremble();
      data.damageType = data.damageType || "normal_damage";
      Backend.playSound("./audio/system/" + data.damageType + (data.damageNum > 1 ? "2" : ""));
      break;
    }
    case "LoseHP": {
      Backend.playSound("./audio/system/losehp");
      break;
    }
    case "ChangeMaxHp": {
      if (data.num < 0) {
        Backend.playSound("./audio/system/losemaxhp");
      }
      break;
    }
    case "PlaySkillSound": {
      const skill = data.name;
      // let extension = data.extension;
      let extension;
      let path;
      let dat;

      // try main general
      if (data.general) {
        dat = JSON.parse(Backend.callLuaFunction("GetGeneralData", [data.general]));
        extension = dat.extension;
        path = "./packages/" + extension + "/audio/skill/" + skill + "_" + data.general;
        if (Backend.exists(path + ".mp3") || Backend.exists(path + "1.mp3")) {
          Backend.playSound(path, data.i);
          break;
        }
      }

      // secondly try deputy general
      if (data.deputy) {
        dat = JSON.parse(Backend.callLuaFunction("GetGeneralData", [data.deputy]));
        extension = dat.extension;
        path = "./packages/" + extension + "/audio/skill/" + skill + "_" + data.deputy;
        if (Backend.exists(path + ".mp3") || Backend.exists(path + "1.mp3")) {
          Backend.playSound(path, data.i);
          break;
        }
      }

      // finally normal skill
      dat = JSON.parse(Backend.callLuaFunction("GetSkillData", [skill]));
      extension = dat.extension;
      path = "./packages/" + extension + "/audio/skill/" + skill;
      Backend.playSound(path, data.i);
      break;
    }
    case "PlaySound": {
      Backend.playSound(data.name);
      break;
    }
    case "Death": {
      const item = getPhoto(data.to);
      const extension = JSON.parse(Backend.callLuaFunction("GetGeneralData", [item.general])).extension;
      Backend.playSound("./packages/" + extension + "/audio/death/" + item.general);
    }
    default:
      break;
  }
}

callbacks["GameOver"] = (jsonData) => {
  roomScene.state = "notactive";
  roomScene.popupBox.sourceComponent = Qt.createComponent("../RoomElement/GameOverBox.qml");
  const box = roomScene.popupBox.item;
  box.winner = jsonData;
  // roomScene.isStarted = false;
}

callbacks["FillAG"] = (j) => {
  const data = JSON.parse(j);
  const ids = data[0];
  roomScene.manualBox.sourceComponent = Qt.createComponent("../RoomElement/AG.qml");
  roomScene.manualBox.item.addIds(ids);
}

callbacks["AskForAG"] = (j) => {
  roomScene.state = "replying";
  roomScene.manualBox.item.interactive = true;
}

callbacks["TakeAG"] = (j) => {
  if (!roomScene.manualBox.item) return;
  const data = JSON.parse(j);
  const pid = data[0];
  const cid = data[1];
  const item = getPhoto(pid);
  const general = Backend.translate(item.general);

  // the item should be AG box
  roomScene.manualBox.item.takeAG(general, cid);
}

callbacks["CloseAG"] = () => roomScene.manualBox.item.close();

callbacks["CustomDialog"] = (j) => {
  const data = JSON.parse(j);
  const path = data.path;
  const dat = data.data;
  roomScene.state = "replying";
  roomScene.popupBox.source = AppPath + "/" + path;
  if (dat) {
    roomScene.popupBox.item.loadData(dat);
  }
}

callbacks["UpdateLimitSkill"] = (j) => {
  const data = JSON.parse(j);
  const id = data[0];
  const skill = data[1];
  const time = data[2];

  const photo = getPhoto(id);
  if (photo) {
    photo.updateLimitSkill(skill, time);
  }
}

callbacks["UpdateDrawPile"] = (j) => {
  const data = parseInt(j);
  roomScene.miscStatus.pileNum = data;
}

callbacks["UpdateRoundNum"] = (j) => {
  const data = parseInt(j);
  roomScene.miscStatus.roundNum = data;
}

callbacks["UpdateGameData"] = (j) => {
  const data = JSON.parse(j);
  const id = data[0];
  const total = data[1];
  const win = data[2];
  const run = data[3];
  const photo = getPhoto(id);
  if (photo) {
    photo.totalGame = total;
    photo.winGame = win;
    photo.runGame = run;
  }
}

// 神貂蝉

callbacks["StartChangeSelf"] = (j) => {
  const id = parseInt(j);
  ClientInstance.notifyServer("PushRequest", "changeself," + j);
}

callbacks["ChangeSelf"] = (j) => {
  const data = parseInt(j);
  if (Self.id === data) {
    const msg = mainWindow.fetchMessage();
    if (!msg) return;
    mainWindow.handleMessage(msg.command, msg.jsonData);
    return;
  }
  changeSelf(data);
}

callbacks["AskForLuckCard"] = (j) => {
  // jsonData: int time
  if (config.replaying) return;
  const time = parseInt(j);
  roomScene.setPrompt(Backend.translate("#AskForLuckCard").arg(time), true);
  roomScene.state = "replying";
  roomScene.extra_data = {
    luckCard: true,
    time: time,
  };
  roomScene.okCancel.visible = true;
  roomScene.okButton.enabled = true;
  roomScene.cancelButton.enabled = true;
}

callbacks["CancelRequest"] = (jsonData) => {
  ClientInstance.replyToServer("", "__cancel")
}

callbacks["ReplayerDurationSet"] = (j) => {
  roomScene.replayerDuration = parseInt(j);
}

callbacks["ReplayerElapsedChange"] = (j) => {
  roomScene.replayerElapsed = parseInt(j);
}

callbacks["ReplayerSpeedChange"] = (j) => {
  roomScene.replayerSpeed = parseFloat(j);
}
