var Card = {
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

function arrangePhotos() {
  /* Layout of photos:
   * +---------------+
   * |   6 5 4 3 2   |
   * | 7           1 |
   * |   dashboard   |
   * +---------------+
   */

  const photoWidth = 175 * 0.75;
  // Padding is negative, because photos are scaled.
  const roomAreaPadding = -16;
  const verticalPadding = -175 / 8;
  const horizontalSpacing = 32;
  let verticalSpacing = (roomArea.width - photoWidth * 7) / 8;

  // Position 1-7
  let startX = verticalPadding + verticalSpacing;
  let padding = photoWidth + verticalSpacing;
  let regions = [
    { x: startX + padding * 6, y: roomAreaPadding + horizontalSpacing * 3 },
    { x: startX + padding * 5, y: roomAreaPadding + horizontalSpacing },
    { x: startX + padding * 4, y: roomAreaPadding },
    { x: startX + padding * 3, y: roomAreaPadding },
    { x: startX + padding * 2, y: roomAreaPadding },
    { x: startX + padding, y: roomAreaPadding + horizontalSpacing },
    { x: startX, y: roomAreaPadding + horizontalSpacing * 3 },
  ];

  const regularSeatIndex = [
    [4],
    [3, 5],
    [1, 4, 7],
    [1, 3, 5, 7],
    [1, 3, 4, 5, 7],
    [1, 2, 3, 5, 6, 7],
    [1, 2, 3, 4, 5, 6, 7],
  ];
  let seatIndex = regularSeatIndex[playerNum - 2];

  let item, region, i;

  for (i = 0; i < playerNum - 1; i++) {
    item = photos.itemAt(i);
    if (!item)
      continue;

    region = regions[seatIndex[photoModel.get(i).index] - 1];
    item.x = region.x;
    item.y = region.y;
  }
}

function doOkButton() {
  if (roomScene.state == "playing" || roomScene.state == "responding") {
    replyToServer(JSON.stringify(
      {
        card: dashboard.getSelectedCard(),
        targets: selected_targets
      }
    ));
    return;
  } 
  replyToServer("1");
}

function doCancelButton() {
  if (roomScene.state == "playing") {
    dashboard.stopPending();
    dashboard.deactivateSkillButton();
    dashboard.unSelectAll();
    dashboard.enableCards();
    dashboard.enableSkills();
    return;
  } else if (roomScene.state == "responding") {
    dashboard.stopPending();
    dashboard.deactivateSkillButton();
    dashboard.unSelectAll();
    replyToServer("__cancel");
    return;
  }
   
  replyToServer("__cancel");
}

function replyToServer(jsonData) {
  roomScene.state = "notactive";
  ClientInstance.replyToServer("", jsonData);
}

function getPhotoModel(id) {
  for (let i = 0; i < photoModel.count; i++) {
    let item = photoModel.get(i);
    if (item.id === id) {
      return item;
    }
  }
  return undefined;
}

function getPhoto(id) {
  for (let i = 0; i < photoModel.count; i++) {
    let item = photoModel.get(i);
    if (item.id === id) {
      return photos.itemAt(i);
    }
  }
  return undefined;
}

function getPhotoOrDashboard(id) {
  let photo = getPhoto(id);
  if (!photo) {
    if (id === Self.id)
      return dashboard;
  }
  return photo;
}

function getPhotoOrSelf(id) {
  let photo = getPhoto(id);
  if (!photo) {
    if (id === Self.id)
      return dashboard.self;
  }
  return photo;
}

function getAreaItem(area, id) {
  if (area === Card.DrawPile) {
    return drawPile;
  } else if (area === Card.DiscardPile || area === Card.Processing) {
    return tablePile;
  } else if (area === Card.AG) {
    return popupBox.item;
  }

  let photo = getPhotoOrDashboard(id);
  if (!photo) {
    return null;
  }

  if (area === Card.PlayerHand) {
    return photo.handcardArea;
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
    let move = moves[i];
    let from = getAreaItem(move.fromArea, move.from);
    let to = getAreaItem(move.toArea, move.to);
    if (!from || !to || from === to)
      continue;
    let items = from.remove(move.ids);
    if (items.length > 0)
      to.add(items);
    to.updateCardPosition(true);
  }
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
    return;
  }
  if (!Backend.isDir(path)) {
    // TODO: set picture emotion
    return;
  }
  let component = Qt.createComponent("RoomElement/PixmapAnimation.qml");
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
      if (id === dashboardModel.id) {
        photo = dashboard.self;
      } else {
        return null;
      }
    }
  }

  let animation = component.createObject(photo, {source: emotion});
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

function changeHp(id, delta, losthp) {
  let photo = getPhoto(id);
  if (!photo) {
    if (id === dashboardModel.id) {
      photo = dashboard.self;
    } else {
      return null;
    }
  }
  if (delta < 0) {
    if (!losthp) {
      setEmotion(id, "damage")
      photo.tremble()
    }
  }
}

function doIndicate(from, tos) {
  let component = Qt.createComponent("RoomElement/IndicatorLine.qml");
  if (component.status !== Component.Ready)
    return;

  let fromItem = getPhotoOrDashboard(from);
  let fromPos = mapFromItem(fromItem, fromItem.width / 2, fromItem.height / 2);

  let end = [];
  for (let i = 0; i < tos.length; i++) {
    if (from === tos[i])
      continue;
    let toItem = getPhotoOrDashboard(tos[i]);
    let toPos = mapFromItem(toItem, toItem.width / 2, toItem.height / 2);
    end.push(toPos);
  }

  let color = "#96943D";
  let line = component.createObject(roomScene, {start: fromPos, end: end, color: color});
  line.finished.connect(() => line.destroy());
  line.running = true;
}

callbacks["AddPlayer"] = function(jsonData) {
  // jsonData: int id, string screenName, string avatar
  for (let i = 0; i < photoModel.count; i++) {
    let item = photoModel.get(i);
    if (item.id === -1) {
      let data = JSON.parse(jsonData);
      let uid = data[0];
      let name = data[1];
      let avatar = data[2];
      item.id = uid;
      item.screenName = name;
      item.general = avatar;
      return;
    }
  }
}

function enableTargets(card) { // card: int | { skill: string, subcards: int[] }
  if (roomScene.respond_play) {
    let candidate = (!isNaN(card) && card !== -1) || typeof(card) === "string";
    if (candidate) {
      okButton.enabled = JSON.parse(Backend.callLuaFunction(
        "CardFitPattern",
        [card, roomScene.responding_card]
      ));
    } else {
      okButton.enabled = false;
    }
    return;
  }

  let i = 0;
  let candidate = (!isNaN(card) && card !== -1) || typeof(card) === "string";
  let all_photos = [dashboard.self];
  for (i = 0; i < playerNum - 1; i++) {
    all_photos.push(photos.itemAt(i))
  }
  selected_targets = [];
  for (i = 0; i < playerNum; i++) {
    all_photos[i].selected = false;
  }

  if (candidate) {
    let data = {
      ok_enabled: false,
      enabled_targets: []
    }

    all_photos.forEach(photo => {
      photo.state = "candidate";
      let id = photo.playerid;
      let ret = JSON.parse(Backend.callLuaFunction(
        "CanUseCardToTarget",
        [card, id, selected_targets]
      ));
      photo.selectable = ret;
    })

    okButton.enabled = JSON.parse(Backend.callLuaFunction(
      "CardFeasible", [card, selected_targets]
    ));
    if (okButton.enabled && roomScene.state === "responding") {
      okButton.enabled = JSON.parse(Backend.callLuaFunction(
        "CardFitPattern",
        [card, roomScene.responding_card]
      ));
    } else if (okButton.enabled && roomScene.state == "playing") {
      okButton.enabled = JSON.parse(Backend.callLuaFunction("CanUseCard", [card, Self.id]));
    }
    if (okButton.enabled) {
      if (roomScene.extra_data instanceof Object) {
        let must = roomScene.extra_data.must_targets;
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
  let card = dashboard.getSelectedCard();
  let candidate = (!isNaN(card) && card !== -1) || typeof(card) === "string";
  let all_photos = [dashboard.self]
  for (i = 0; i < playerNum - 1; i++) {
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
      let id = photo.playerid;
      let ret = JSON.parse(Backend.callLuaFunction(
        "CanUseCardToTarget",
        [card, id, selected_targets]
      ));
      photo.selectable = ret;
    })

    okButton.enabled = JSON.parse(Backend.callLuaFunction(
      "CardFeasible", [card, selected_targets]
    ));
    if (okButton.enabled && roomScene.state === "responding") {
      okButton.enabled = JSON.parse(Backend.callLuaFunction(
        "CardFitPattern",
        [card, roomScene.responding_card]
      ));
    } else if (okButton.enabled && roomScene.state == "playing") {
      okButton.enabled = JSON.parse(Backend.callLuaFunction("CanUseCard", [card, Self.id]));
    }
    if (okButton.enabled) {
      if (roomScene.extra_data instanceof Object) {
        let must = roomScene.extra_data.must_targets;
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

callbacks["RemovePlayer"] = function(jsonData) {
  // jsonData: int uid
  let uid = JSON.parse(jsonData)[0];
  let model = getPhotoModel(uid);
  if (typeof(model) !== "undefined") {
    model.id = -1;
    model.screenName = "";
    model.general = "";
  }
}

callbacks["RoomOwner"] = function(jsonData) {
  // jsonData: int uid of the owner
  let uid = JSON.parse(jsonData)[0];

  if (dashboardModel.id === uid) {
    dashboardModel.isOwner = true;
    roomScene.dashboardModelChanged();
    return;
  }

  let model = getPhotoModel(uid);
  if (typeof(model) !== "undefined") {
    model.isOwner = true;
  }
}

callbacks["PropertyUpdate"] = function(jsonData) {
  // jsonData: int id, string property_name, value
  let data = JSON.parse(jsonData);
  let uid = data[0];
  let property_name = data[1];
  let value = data[2];

  if (Self.id === uid) {
    dashboardModel[property_name] = value;
    roomScene.dashboardModelChanged();
    return;
  }

  let model = getPhotoModel(uid);
  if (typeof(model) !== "undefined") {
    model[property_name] = value;
  }
}

callbacks["ArrangeSeats"] = function(jsonData) {
  // jsonData: seat order
  let order = JSON.parse(jsonData);
  roomScene.isStarted = true;

  for (let i = 0; i < photoModel.count; i++) {
    let item = photoModel.get(i);
    item.seatNumber = order.indexOf(item.id) + 1;
    item.general = "";
  }

  dashboardModel.seatNumber = order.indexOf(Self.id) + 1;
  dashboardModel.general = "";
  roomScene.dashboardModelChanged();
  
  // make Self to the first of list, then reorder photomodel
  let selfIndex = order.indexOf(Self.id);
  let after = order.splice(selfIndex);
  after.push(...order);
  let photoOrder = after.slice(1);

  for (let i = 0; i < photoModel.count; i++) {
    let item = photoModel.get(i);
    item.index = photoOrder.indexOf(item.id);
  }
  
  arrangePhotos();
}

function cancelAllFocus() {
  let item;
  for (let i = 0; i < playerNum - 1; i++) {
    item = photos.itemAt(i);
    item.progressBar.visible = false;
    item.progressTip = "";
  }
}

callbacks["MoveFocus"] = function(jsonData) {
  // jsonData: int[] focuses, string command
  cancelAllFocus();
  let data = JSON.parse(jsonData);
  let focuses = data[0];
  let command = data[1];
  
  let item, model;
  for (let i = 0; i < playerNum - 1; i++) {
    model = photoModel.get(i);
    if (focuses.indexOf(model.id) != -1) {
      item = photos.itemAt(i);
      item.progressBar.visible = true;
      item.progressTip = Backend.translate(command) 
        + Backend.translate(" thinking...");

      if (command === "PlayCard") {
        item.playing = true;
      }
    } else {
      item = photos.itemAt(i);
      if (command === "PlayCard") {
        item.playing = false;
      }
    }
  }

  if (command === "PlayCard") {
    if (focuses.indexOf(Self.id) != -1) {
      dashboard.self.playing = true;
    } else {
      dashboard.self.playing = false;
    }
  }
}

callbacks["PlayerRunned"] = function(jsonData) {
  // jsonData: int runner, int robot
  let data = JSON.parse(jsonData);
  let runner = data[0];
  let robot = data[1];

  let model = getPhotoModel(runner);
  if (typeof(model) !== "undefined") {
    model.id = robot;
  }
}

callbacks["AskForGeneral"] = function(jsonData) {
  // jsonData: string[] Generals
  // TODO: choose multiple generals
  let data = JSON.parse(jsonData);
  roomScene.promptText = Backend.translate("#AskForGeneral");
  roomScene.state = "replying";
  roomScene.popupBox.source = "RoomElement/ChooseGeneralBox.qml";
  let box = roomScene.popupBox.item;
  box.choiceNum = 1;
  box.accepted.connect(() => {
    replyToServer(JSON.stringify([box.choices[0]]));
  });
  for (let i = 0; i < data.length; i++)
    box.generalList.append({ "name": data[i] });
  box.updatePosition();
}

callbacks["AskForSkillInvoke"] = function(jsonData) {
  // jsonData: string name
  roomScene.promptText = Backend.translate("#AskForSkillInvoke")
    .arg(Backend.translate(jsonData));
  roomScene.state = "replying";
  roomScene.okCancel.visible = true;
  roomScene.okButton.enabled = true;
  roomScene.cancelButton.enabled = true;
}

callbacks["AskForGuanxing"] = function(jsonData) {
  let data = JSON.parse(jsonData);
  let cards = [];

  roomScene.state = "replying";
  roomScene.popupBox.source = "RoomElement/GuanxingBox.qml";
  data.cards.forEach(id => {
    let d = Backend.callLuaFunction("GetCardData", [id]);
    cards.push(JSON.parse(d));
  });
  let box = roomScene.popupBox.item;
  box.areaCapacities = [cards.length, cards.length];
  box.areaNames = ["Top", "Bottom"];
  box.cards = cards;
  box.arrangeCards();
  box.accepted.connect(() => {
    replyToServer(JSON.stringify(box.getResult()));
  });
}

callbacks["AskForChoice"] = function(jsonData) {
  // jsonData: [ string[] choices, string skill ]
  // TODO: multiple choices, e.g. benxi_ol
  let data = JSON.parse(jsonData);
  let choices = data[0];
  let skill_name = data[1];
  let prompt = data[2];
  if (prompt === "") {
    roomScene.promptText = Backend.translate("#AskForChoice")
      .arg(Backend.translate(skill_name));
  } else {
    roomScene.promptText = processPrompt(prompt);
  }
  roomScene.state = "replying";
  roomScene.popupBox.source = "RoomElement/ChoiceBox.qml";
  let box = roomScene.popupBox.item;
  box.options = choices;
  box.skill_name = skill_name;
  box.accepted.connect(() => {
    replyToServer(choices[box.result]);
  });
}

callbacks["AskForCardChosen"] = function(jsonData) {
  // jsonData: [ int[] handcards, int[] equips, int[] delayedtricks,
  //  string reason ]
  let data = JSON.parse(jsonData);
  let handcard_ids = data[0];
  let equip_ids = data[1];
  let delayedTrick_ids = data[2];
  let reason = data[3];
  let handcards = [];
  let equips = [];
  let delayedTricks = [];

  handcard_ids.forEach(id => {
    let card_data = JSON.parse(Backend.callLuaFunction("GetCardData", [id]));
    handcards.push(card_data);
  });

  equip_ids.forEach(id => {
    let card_data = JSON.parse(Backend.callLuaFunction("GetCardData", [id]));
    equips.push(card_data);
  });

  delayedTrick_ids.forEach(id => {
    let card_data = JSON.parse(Backend.callLuaFunction("GetCardData", [id]));
    delayedTricks.push(card_data);
  });

  roomScene.promptText = Backend.translate("#AskForChooseCard")
    .arg(Backend.translate(reason));
  roomScene.state = "replying";
  roomScene.popupBox.source = "RoomElement/PlayerCardBox.qml";
  let box = roomScene.popupBox.item;
  box.addHandcards(handcards);
  box.addEquips(equips);
  box.addDelayedTricks(delayedTricks);
  roomScene.popupBox.moveToCenter();
  box.cardSelected.connect(function(cid){
    replyToServer(cid);
  });
}

callbacks["MoveCards"] = function(jsonData) {
  // jsonData: merged moves
  let moves = JSON.parse(jsonData);
  moveCards(moves);
}

callbacks["PlayCard"] = function(jsonData) {
  // jsonData: int playerId
  let playerId = parseInt(jsonData);
  if (playerId == Self.id) {
    roomScene.promptText = Backend.translate("#PlayCard");
    roomScene.state = "playing";
    okButton.enabled = false;
  }
}

callbacks["LoseSkill"] = function(jsonData) {
  // jsonData: [ int player_id, string skill_name ]
  let data = JSON.parse(jsonData);
  let id = data[0];
  let skill_name = data[1];
  if (id === Self.id) {
    dashboard.loseSkill(skill_name);
  }
}

callbacks["AddSkill"] = function(jsonData) {
  // jsonData: [ int player_id, string skill_name ]
  let data = JSON.parse(jsonData);
  let id = data[0];
  let skill_name = data[1];
  if (id === Self.id) {
    dashboard.addSkill(skill_name);
  }
}

// prompt: 'string:<src>:<dest>:<arg>:<arg2>'
function processPrompt(prompt) {
  let data = prompt.split(":");
  let raw = Backend.translate(data[0]);
  let src = parseInt(data[1]);
  let dest = parseInt(data[2]);
  if (raw.match("%src")) raw = raw.replace("%src", Backend.translate(getPhotoOrSelf(src).general));
  if (raw.match("%dest")) raw = raw.replace("%dest", Backend.translate(getPhotoOrSelf(dest).general));
  if (raw.match("%arg")) raw = raw.replace("%arg", Backend.translate(data[3]));
  if (raw.match("%arg2")) raw = raw.replace("%arg2", Backend.translate(data[4]));
  return raw;
}

callbacks["AskForUseActiveSkill"] = function(jsonData) {
  // jsonData: string skill_name, string prompt
  let data = JSON.parse(jsonData);
  let skill_name = data[0];
  let prompt = data[1];
  let cancelable = data[2];
  if (prompt === "") {
    roomScene.promptText = Backend.translate("#AskForUseActiveSkill")
      .arg(Backend.translate(skill_name));
  } else {
    roomScene.promptText = processPrompt(prompt);
  }

  roomScene.respond_play = false;
  roomScene.state = "responding";
  dashboard.startPending(skill_name);
  cancelButton.enabled = cancelable;
}

callbacks["CancelRequest"] = function() {
  roomScene.state = "notactive";
}

callbacks["GameLog"] = function(jsonData) {
  roomScene.addToLog(jsonData)
}

callbacks["AskForUseCard"] = function(jsonData) {
  // jsonData: card, pattern, prompt, cancelable, {}
  let data = JSON.parse(jsonData);
  let cardname = data[0];
  let pattern = data[1];
  let prompt = data[2];
  let extra_data = data[4];
  if (extra_data != null) {
    roomScene.extra_data = extra_data;
  }

  if (prompt === "") {
    roomScene.promptText = Backend.translate("#AskForUseCard")
      .arg(Backend.translate(cardname));
  } else {
    roomScene.promptText = processPrompt(prompt);
  }
  roomScene.responding_card = pattern;
  roomScene.respond_play = false;
  roomScene.state = "responding";
  okButton.enabled = false;
  cancelButton.enabled = true;
}

callbacks["AskForResponseCard"] = function(jsonData) {
  // jsonData: card_name, pattern, prompt, cancelable, {}
  let data = JSON.parse(jsonData);
  let cardname = data[0];
  let pattern = data[1];
  let prompt = data[2];

  if (prompt === "") {
    roomScene.promptText = Backend.translate("#AskForResponseCard")
      .arg(Backend.translate(cardname));
  } else {
    roomScene.promptText = processPrompt(prompt);
  }
  roomScene.responding_card = pattern;
  roomScene.respond_play = true;
  roomScene.state = "responding";
  okButton.enabled = false;
  cancelButton.enabled = true;
}

callbacks["WaitForNullification"] = function() {
  roomScene.state = "notactive";
}

callbacks["SetPlayerMark"] = function(jsonData) {
  let data = JSON.parse(jsonData);
  let player = getPhotoOrSelf(data[0]);
  let mark = data[1];
  let value = data[2];
  if (value == 0) {
    player.markArea.removeMark(mark);
  } else {
    player.markArea.setMark(mark, mark.startsWith("@@") ? "" : value);
  }
}

callbacks["Animate"] = function(jsonData) {
  // jsonData: [Object object]
  let data = JSON.parse(jsonData);
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
    case "SuperLightBox":
      break;
    case "InvokeSkill": {
      let id = data.player;
      let component = Qt.createComponent("RoomElement/SkillInvokeAnimation.qml");
      if (component.status !== Component.Ready)
        return;

      let photo = getPhoto(id);
      if (!photo) {
        if (id === dashboardModel.id) {
          photo = dashboard.self;
        } else {
          return null;
        }
      }

      let animation = component.createObject(photo, {
        skill_name: Backend.translate(data.name),
        skill_type: (data.skill_type ? data.skill_type : "special"),
      });
      animation.anchors.centerIn = photo;
      animation.finished.connect(() => animation.destroy());
      break;
    }
    default:
      break;
  }
}

callbacks["LogEvent"] = function(jsonData) {
  // jsonData: [Object object]
  let data = JSON.parse(jsonData);
  switch (data.type) {
    case "Damage": {
      let item = getPhotoOrDashboard(data.to);
      setEmotion(data.to, "damage");
      item.tremble();
      Backend.playSound("./audio/system/" + data.damageType + (data.damageNum > 1 ? "2" : ""));
      break;
    }
    case "LoseHP": {
      Backend.playSound("./audio/system/losehp");
      break;
    }
    case "PlaySkillSound": {
      let skill = data.name;
      let extension = data.extension;
      if (!extension) {
        let data = JSON.parse(Backend.callLuaFunction("GetSkillData", [skill]));
        extension = data.extension;
      }
      Backend.playSound("./packages/" + extension + "/audio/skill/" + skill, data.i);
      break;
    }
    case "PlaySound": {
      Backend.playSound(data.name);
      break;
    }
    case "Death": {
      let item = getPhoto(data.to);
      if (data.to === dashboardModel.id) {
        item = dashboard.self;
      }
      let extension = JSON.parse(Backend.callLuaFunction("GetGeneralData", [item.general])).extension;
      Backend.playSound("./packages/" + extension + "/audio/death/" + item.general);
    }
    default:
      break;
  }
}

callbacks["GameOver"] = function(jsonData) {
  roomScene.state = "notactive";
  roomScene.popupBox.source = "RoomElement/GameOverBox.qml";
  let box = roomScene.popupBox.item;
  box.winner = jsonData;
  roomScene.isStarted = false;
}
