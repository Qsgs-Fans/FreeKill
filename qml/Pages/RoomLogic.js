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

  const photoWidth = 175;
  const roomAreaPadding = 10;
  let verticalPadding = Math.max(10, roomArea.width * 0.01);
  let horizontalSpacing = Math.max(30, roomArea.height * 0.1);
  let verticalSpacing = (roomArea.width - photoWidth * 7 - verticalPadding * 2) / 6;

  // Position 1-7
  const regions = [
    { x: verticalPadding + (photoWidth + verticalSpacing) * 6, y: roomAreaPadding + horizontalSpacing * 2 },
    { x: verticalPadding + (photoWidth + verticalSpacing) * 5, y: roomAreaPadding + horizontalSpacing },
    { x: verticalPadding + (photoWidth + verticalSpacing) * 4, y: roomAreaPadding },
    { x: verticalPadding + (photoWidth + verticalSpacing) * 3, y: roomAreaPadding },
    { x: verticalPadding + (photoWidth + verticalSpacing) * 2, y: roomAreaPadding },
    { x: verticalPadding + photoWidth + verticalSpacing, y: roomAreaPadding + horizontalSpacing },
    { x: verticalPadding, y: roomAreaPadding + horizontalSpacing * 2 },
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
  if (roomScene.state == "playing") {
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
  replyToServer("");
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
  } else if (area === Card.PlayerEquip)
    return photo.equipArea;
  else if (area === Card.PlayerJudge)
    return photo.delayedTrickArea;
  else if (area === Card.PlayerSpecial)
    return photo.specialArea;

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

function setEmotion(id, emotion) {
  let component = Qt.createComponent("RoomElement/PixmapAnimation.qml");
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

  let animation = component.createObject(photo, {source: emotion, anchors: {centerIn: photo}});
  animation.finished.connect(() => animation.destroy());
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
  }

  dashboardModel.seatNumber = order.indexOf(Self.id) + 1;
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
  roomScene.state = "responding";
}

callbacks["AskForChoice"] = function(jsonData) {
  // jsonData: [ string[] choices, string skill ]
  // TODO: multiple choices, e.g. benxi_ol
  let data = JSON.parse(jsonData);
  let choices = data[0];
  let skill_name = data[1];
  roomScene.promptText = Backend.translate("#AskForChoice")
    .arg(Backend.translate(jsonData));;
  roomScene.state = "replying";
  roomScene.popupBox.source = "RoomElement/ChoiceBox.qml";
  let box = roomScene.popupBox.item;
  box.options = choices;
  box.skill_name = skill_name;
  box.accepted.connect(() => {
    replyToServer(choices[box.result]);
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
  }
}
