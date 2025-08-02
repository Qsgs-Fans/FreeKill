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
  let photoWidth = (roomArea.width - horizontalSpacing * playerNum)
                 / (playerNum - 1);
  let photoScale = 0.75;
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

function replyToServer(jsonData) {
  ClientInstance.replyToServer("", jsonData);
  roomScene.state = "notactive";
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
  } else if (area === Card.DiscardPile || area === Card.Processing ||
             area === Card.Void) {
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

function moveCards(data) {
  const moves = data.merged;
  for (let i = 0; i < moves.length; i++) {
    const move = moves[i];
    const from = getAreaItem(move.fromArea, move.from);
    const to = getAreaItem(move.toArea, move.to);
    if (!from || !to)
      continue;
    const items = from.remove(move.ids, move.fromSpecialName, data);
    items.forEach((item) => item.known = !!data[item.cid.toString()]); // updata card visible. must be before move animation
    if (from === to && from !== tablePile) // decide whether to play the move animation
      continue;
    //items.forEach((item) => item.markVisible = (to === dashboard.handcardArea)); // cardMark only visible in my handcardArea
    if (to === tablePile) {
      let vanished = items.filter(c => c.cid === -1);
      if (vanished.length > 0) {
        drawPile.add(vanished, move.specialName);
        drawPile.updateCardPosition(true);
      }
      vanished = items.filter(c => c.cid !== -1);
      if (vanished.length > 0) {
        to.add(vanished, move.specialName);
        to.updateCardPosition(true);
      }
    } else {
      if (items.length > 0)
        to.add(items, move.specialName);
      to.updateCardPosition(true);
    }
  }
}

const suitInteger = {
  spade: 1, heart: 3,
  club: 2, diamond: 4,
}

function sortHandcards(sortMethods) {
  if (!dashboard.handcardArea.cards.length) {
    return;
  }

  const cardType = sortMethods[0];
  const cardNum = sortMethods[1];
  const cardSuit = sortMethods[2];

  if (!cardType && !cardNum && !cardSuit) {
    return;
  }

  let sortOutputs = [];
  let sortedStatus = [];

  const subtypeString2Number = {
    ["none"]: Card.SubtypeNone,
    ["delayed_trick"]: Card.SubtypeDelayedTrick,
    ["weapon"]: Card.SubtypeWeapon,
    ["armor"]: Card.SubtypeArmor,
    ["defensive_horse"]: Card.SubtypeDefensiveRide,
    ["offensive_horse"]: Card.SubtypeOffensiveRide,
    ["treasure"]: Card.SubtypeTreasure,
  }

  const others = [];
  const hands = [];
  const orignal_hands = lcall("GetPlayerHandcards", Self.id); // 不计入expand_pile

  dashboard.handcardArea.cards.forEach(c => {
    if (orignal_hands.includes(c.cid)) {
      hands.push(c);
    } else {
      others.push(c);
    }
  })

  const orignal = hands.map(c => {
    return c.cid;
  })


  let sortedByType = true;
  let handcards
  if (cardType) {
    handcards = hands.slice(0);
    handcards.sort((prev, next) => {
      if (prev.footnote === next.footnote) {
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
      } else {
        return prev.footnote > next.footnote ? 1 : -1;
      }
    });

    // Check if the cards are sorted by type
    let i = 0;
    handcards.every(c => {
      if (orignal[i] !== c.cid) {
        sortedByType = false;
        return false;
      }
      i++;
      return true;
    })
    sortOutputs.push(handcards);
    sortedStatus.push(sortedByType);
  }

  let sortedByNum = true;
  if (cardNum) {
    handcards = hands.slice(0);
    handcards.sort((prev, next) => {
      if (prev.footnote === next.footnote) {
        if (prev.number === next.number) {
          if (suitInteger[prev.suit] === suitInteger[next.suit]) {
            return prev.cid - next.cid;
          } else {
            return suitInteger[prev.suit] - suitInteger[next.suit];
          }
        } else {
          return prev.number - next.number;
        }
      } else {
        return prev.footnote > next.footnote ? 1 : -1;
      }
    });

    let i = 0;
    handcards.every(c => {
      if (orignal[i] !== c.cid) {
        sortedByNum = false;
        return false;
      }
      i++;
      return true;
    })
    sortOutputs.push(handcards);
    sortedStatus.push(sortedByNum);
  }

  let sortedBySuit = true;
  if (cardSuit) {
    handcards = hands.slice(0);
    handcards.sort((prev, next) => {
      if (prev.footnote === next.footnote) {
        if (suitInteger[prev.suit] === suitInteger[next.suit]) {
          if (prev.number === next.number) {
            return prev.cid - next.cid;
          } else {
            return prev.number - next.number;
          }
        } else {
          return suitInteger[prev.suit] - suitInteger[next.suit];
        }
      } else {
        return prev.footnote > next.footnote ? 1 : -1;
      }
    });

    let i = 0;
    handcards.every(c => {
      if (orignal[i] !== c.cid) {
        sortedBySuit = false;
        return false;
      }
      i++;
      return true;
    })
    sortOutputs.push(handcards);
    sortedStatus.push(sortedBySuit);
  }
  let output
  for (let i = 0; i < sortedStatus.length; i++) {
    if (sortedStatus[i]) {
      let j = i < sortedStatus.length - 1 ? i + 1 : 0;
      output = sortOutputs[j];
      break;
    }
  }
  if (!output) output = sortOutputs[0];
  others.forEach(c => {
    output.push(c);
  });
  /*
  console.log("----------------------");
  dashboard.handcardArea.cards.forEach(c => {
    console.log("handcards: " + c.cid);
  });
  console.log("----------------------");
  others.forEach(c => {
    console.log("others: " + c.cid);
  });
  console.log("----------------------");
  output.forEach(c => {
    console.log("output: " + c.cid);
  });
  console.log("----------------------");
  */
  dashboard.handcardArea.cards = output;
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

  const animation = component.createObject(photo,
                    { source: (OS === "Win" ? "file:///" : "") + path });
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

callbacks["SetCardFootnote"] = (data) => {
  const [id, note] = data;
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

callbacks["SetCardVirtName"] = (data) => {
  const [ids, note] = data;
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
  const line = component.createObject(roomScene, {
                                        start: fromPos,
                                        end: end,
                                        color: color
                                      });
  line.finished.connect(() => line.destroy());
  line.running = true;
}

function getPlayerStr(playerid) {
  const photo = getPhoto(playerid);
  if (photo.general === "anjiang" && (photo.deputyGeneral === "anjiang" || !photo.deputyGeneral)) {
    let ret = luatr("seat#" + photo.seatNumber);
    if (playerid == Self.id) {
      ret = ret + luatr("playerstr_self")
    }
    return luatr(ret);
  }

  let ret = photo.general;
  ret = luatr(ret);
  if (photo.deputyGeneral && photo.deputyGeneral !== "") {
    ret = ret + "/" + luatr(photo.deputyGeneral);
  }
  if (playerid == Self.id) {
    ret = ret + luatr("playerstr_self")
  }
  return ret;
}

function processPrompt(prompt) {
  const data = prompt.split(":");
  let raw = luatr(data[0]);
  const src = parseInt(data[1]);
  const dest = parseInt(data[2]);
  if (raw.match("%src"))
    raw = raw.replace(/%src/g, getPlayerStr(src));
  if (raw.match("%dest"))
    raw = raw.replace(/%dest/g, getPlayerStr(dest));

  if (data.length > 3) {
    for (let i = data.length - 1; i > 3; i--) {
      raw = raw.replace(new RegExp("%arg" + (i - 2), "g"), luatr(data[i]));
    }

    raw = raw.replace(new RegExp("%arg", "g"), luatr(data[3]));
  }
  return raw;
}

callbacks["MaxCard"] = (data) => {
  const id = data.id;
  const cardMax = data.pcardMax;
  const hp = data.php;
  const photo = getPhoto(id);
  if (photo) {
    photo.maxCard = cardMax;
    photo.hp = hp;
  }
}

callbacks["AddPlayer"] = (data) => {
  // jsonData: int id, string screenName, string avatar, bool ready
  for (let i = 0; i < photoModel.count; i++) {
    const item = photoModel.get(i);
    if (item.id === -1) {
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
      roomScene.playersAltered = true;

      return;
    }
  }
}

callbacks["RemovePlayer"] = (data) => {
  // jsonData: int uid
  const uid = data[0];
  const model = getPhotoModel(uid);
  if (typeof(model) !== "undefined") {
    model.id = -1;
    model.screenName = "";
    model.general = "";
    model.isOwner = false;
    roomScene.isFull = false;
    roomScene.playersAltered = true;
  }
}

callbacks["RoomOwner"] = (data) => {
  // jsonData: int uid of the owner
  const uid = data[0];

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

callbacks["ReadyChanged"] = (data) => {
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

callbacks["NetStateChanged"] = (data) => {
  const id = data[0];
  let state = data[1];

  const model = getPhotoModel(id);
  if (!model) return;
  if (state === "run" && model.dead) {
    state = "leave";
  }
  model.netstate = state;
}

callbacks["PropertyUpdate"] = (data) => {
  // jsonData: int id, string property_name, value
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

callbacks["UpdateHandcard"] = (j) => {
  const id = parseInt(j);
  const sortable = lcall("CanSortHandcards", Self.id);
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

  card.setData(lcall("GetCardData", id));
  card.draggable = sortable;
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

  card.setData(lcall("GetCardData", id));
}

callbacks["UpdateSkill"] = (j) => {
  const sortable = lcall("CanSortHandcards", Self.id);
  dashboard.sortable = sortable;
  dashboard.handcardArea.sortable = sortable;
  const all_skills = [roomScene.dashboard.skillButtons, roomScene.dashboard.notActiveButtons];
  for (const skills of all_skills) {
    for (let i = 0; i < skills.count; i++) {
      const item = skills.itemAt(i);
      const dat = lcall("GetSkillStatus", item.orig);
      item.locked = dat.locked;
      item.times = dat.times;
    }
  }
}

callbacks["StartGame"] = (jsonData) => {
  roomScene.isStarted = true;

  for (let i = 0; i < photoModel.count; i++) {
    const item = photoModel.get(i);
    item.ready = false;
    item.general = "";
  }
}

callbacks["ArrangeSeats"] = (order) => {
  // jsonData: seat order

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

callbacks["MoveFocus"] = (data) => {
  // jsonData: int[] focuses, string command
  cancelAllFocus();
  const focuses = data[0];
  const command = data[1];
  const timeout = data[2] ?? (config.roomTimeout * 1000);

  let item, model;
  for (let i = 0; i < playerNum; i++) {
    model = photoModel.get(i);
    if (focuses.indexOf(model.id) != -1) {
      item = photos.itemAt(i);
      item.progressBar.duration = timeout;
      item.progressBar.visible = true;
      item.progressTip = luatr(command)
        + luatr(" thinking...");
    }
  }
}

callbacks["PlayerRunned"] = (data) => {
  // jsonData: int runner, int robot
  const runner = data[0];
  const robot = data[1];

  const model = getPhotoModel(runner);
  if (typeof(model) !== "undefined") {
    model.id = robot;
  }
}

callbacks["AskForGeneral"] = (data) => {
  // jsonData: string[] generals, integer n, boolean no_convert, boolean heg, string rule, table extra_data
  //const {generals, n, no_convert, heg, rule, extra_data } = data;
  const generals = data[0];
  const n = data[1];
  const no_convert = data[2];
  const heg = data[3];
  const rule = data[4];
  const extra_data = data[5];

  roomScene.setPrompt(luatr("#AskForGeneral"), true);
  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("../RoomElement/ChooseGeneralBox.qml");
  const box = roomScene.popupBox.item;
  box.accepted.connect(() => {
    replyToServer(box.choices);
  });
  box.generals = generals;
  box.choiceNum = n ?? 1;
  box.convertDisabled = !!no_convert;
  box.hegemony = !!heg;
  box.rule_type = rule ?? (heg? "heg_general_choose" : "askForGeneralsChosen"); // 若heg为true，默认应用国战选将
  box.extra_data = extra_data ?? { n : n };
  for (let i = 0; i < generals.length; i++)
    box.generalList.append({ "name": generals[i] });
  box.updatePosition();
  box.refreshPrompt();
}

callbacks["AskForSkillInvoke"] = (data) => {
  // jsonData: [ string name, string prompt ]
  const skill = data[0];
  const prompt = data[1];
  roomScene.promptText = prompt ? processPrompt(prompt)
                              : luatr("#AskForSkillInvoke").arg(luatr(skill));
  // roomScene.activate();
  // roomScene.okCancel.visible = true;
  // roomScene.okButton.enabled = true;
  // roomScene.cancelButton.enabled = true;
  roomScene.activate();
}

callbacks["AskForArrangeCards"] = (data) => {
  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("../RoomElement/ArrangeCardsBox.qml");
  const box = roomScene.popupBox.item;
  const cards = data.cards;
  box.cards = cards.reduce((newArray, elem) => {
    return newArray.concat(elem.map(cid => lcall("GetCardData", cid)));
  }, []);
  box.org_cards = cards;
  box.prompt = data.prompt;
  box.size = data.size;
  box.areaCapacities = data.capacities;
  box.areaLimits = data.limits;
  box.free_arrange = data.is_free;
  box.areaNames = data.names;
  box.pattern = data.pattern;
  box.poxi_type = data.poxi_type;
  box.cancelable = data.cancelable;

  box.initializeCards();
}

callbacks["AskForGuanxing"] = (data) => {
  const cards = data.cards;
  const min_top_cards = data.min_top_cards;
  const max_top_cards = data.max_top_cards;
  const min_bottom_cards = data.min_bottom_cards;
  const max_bottom_cards = data.max_bottom_cards;
  const top_area_name = data.top_area_name;
  const bottom_area_name = data.bottom_area_name;
  const prompt = data.prompt;
  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("../RoomElement/GuanxingBox.qml");
  const box = roomScene.popupBox.item;
  box.prompt = prompt;
  box.free_arrange = data.is_free;
  if (max_top_cards === 0) {
    box.areaCapacities = [max_bottom_cards];
    box.areaLimits = [min_bottom_cards];
    box.areaNames = [luatr(bottom_area_name)];
  } else {
    if (max_bottom_cards === 0) {
      box.areaCapacities = [max_top_cards];
      box.areaLimits = [min_top_cards];
      box.areaNames = [luatr(top_area_name)];
    } else {
      box.areaCapacities = [max_top_cards, max_bottom_cards];
      box.areaLimits = [min_top_cards, min_bottom_cards];
      box.areaNames = [luatr(top_area_name), luatr(bottom_area_name)];
    }
  }
  box.org_cards = cards;
  box.cards = cards.reduce((newArray, elem) => {
    return newArray.concat(elem.map(cid => lcall("GetCardData", cid)));
  }, []);
  box.initializeCards();
  box.accepted.connect(() => {
    replyToServer(box.getResult());
  });
}

callbacks["AskForExchange"] = (data) => {
  const cards = [];
  const cards_name = [];
  const capacities = [];
  const limits = [];
  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("../RoomElement/GuanxingBox.qml");
  let for_i = 0;
  const box = roomScene.popupBox.item;
  box.org_cards = data.piles;
  data.piles.forEach(ids => {
    if (ids.length > 0) {
      ids.forEach(id => cards.push(lcall("GetCardData", id)));
      capacities.push(ids.length);
      limits.push(0);
      cards_name.push(luatr(data.piles_name[for_i]));
      for_i ++;
    }
  });
  box.cards = cards;
  box.areaCapacities = capacities
  box.areaLimits = limits
  box.areaNames = cards_name
  box.initializeCards();
  box.accepted.connect(() => {
    replyToServer(box.getResult());
  });
}

callbacks["AskForChoice"] = (data) => {
  // jsonData: [ string[] choices, string skill ]
  // TODO: multiple choices, e.g. benxi_ol
  const choices = data[0];
  const all_choices = data[1];
  const skill_name = data[2];
  const prompt = data[3];
  const detailed = data[4];
  if (prompt === "") {
    roomScene.promptText = luatr("#AskForChoice")
      .arg(luatr(skill_name));
  } else {
    roomScene.setPrompt(processPrompt(prompt), true);
  }
  roomScene.activate();
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

callbacks["AskForChoices"] = (data) => {
  // jsonData: [ string[] choices, string skill ]
  // TODO: multiple choices, e.g. benxi_ol
  const choices = data[0];
  const all_choices = data[1];
  const min_num = data[2][0];
  const max_num = data[2][1];
  const cancelable = data[3];
  const skill_name = data[4];
  const prompt = data[5];
  const detailed = data[6];
  if (prompt === "") {
    roomScene.promptText = luatr("#AskForChoices")
      .arg(luatr(skill_name));
  } else {
    roomScene.setPrompt(processPrompt(prompt), true);
  }
  roomScene.activate();
  let qmlSrc;
  if (!detailed) {
    qmlSrc = "../RoomElement/CheckBox.qml";
  } else {
    qmlSrc = "../RoomElement/DetailedCheckBox.qml";
  }
  roomScene.popupBox.sourceComponent = Qt.createComponent(qmlSrc);
  const box = roomScene.popupBox.item;
  box.options = choices;
  box.skill_name = skill_name;
  box.all_options = all_choices;
  box.min_num = min_num;
  box.max_num = max_num;
  box.cancelable = cancelable;
  box.accepted.connect(() => {
    const ret = [];
    box.result.forEach(id => {
      ret.push(all_choices[id]);
    });
    replyToServer(ret);
  });
}

callbacks["AskForCardChosen"] = (data) => {
  // jsonData: [ int[] handcards, int[] equips, int[] delayedtricks,
  //  string reason ]
  const reason = data._reason;
  const prompt = data._prompt;
  if (prompt === "") {
    roomScene.promptText = luatr(processPrompt("#AskForChooseCard:" + data._id))
      .arg(luatr(reason));
  } else {
    roomScene.setPrompt(processPrompt(prompt), true);
  }
  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("../RoomElement/PlayerCardBox.qml");

  const box = roomScene.popupBox.item;
  box.prompt = prompt;
  box.visible_data = data.visible_data ?? {};
  for (let d of data.card_data) {
    const arr = [];
    const ids = d[1];

    ids.forEach(id => arr.push(lcall("GetCardData", id)));
    box.addCustomCards(d[0], arr);
  }

  roomScene.popupBox.moveToCenter();
  box.cardSelected.connect(cid => replyToServer(cid));
}

callbacks["AskForCardsChosen"] = (data) => {
  // jsonData: [ int[] handcards, int[] equips, int[] delayedtricks,
  //  int min, int max, string reason ]
  const min = data._min;
  const max = data._max;
  const reason = data._reason;
  const prompt = data._prompt;
  if (prompt === "") {
    roomScene.promptText = luatr(processPrompt("#AskForChooseCards:" + data._id))
    .arg(luatr(reason)).arg(min).arg(max);
  } else {
    roomScene.setPrompt(processPrompt(prompt), true);
  }

  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("../RoomElement/PlayerCardBox.qml");
  const box = roomScene.popupBox.item;
  box.multiChoose = true;
  box.min = min;
  box.max = max;
  box.prompt = prompt;
  box.visible_data = data.visible_data ?? {};
  for (let d of data.card_data) {
    const arr = [];
    const ids = d[1];

    ids.forEach(id => arr.push(lcall("GetCardData", id)));
    box.addCustomCards(d[0], arr);
  }

  roomScene.popupBox.moveToCenter();
  box.cardsSelected.connect((ids) => {
    replyToServer(ids);
  });
}

callbacks["AskForPoxi"] = (dat) => {
  const { type, data, extra_data, cancelable } = dat;

  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("../RoomElement/PoxiBox.qml");
  const box = roomScene.popupBox.item;
  box.extra_data = extra_data;
  box.poxi_type = type;
  box.card_data = data;
  box.cancelable = cancelable;
  for (let d of data) {
    const arr = [];
    const ids = d[1];

    ids.forEach(id => arr.push(lcall("GetCardData", id)));
    box.addCustomCards(d[0], arr);
  }
  box.refreshPrompt();

  roomScene.popupBox.moveToCenter();
  box.cardsSelected.connect((ids) => {
    replyToServer(ids);
  });
}

callbacks["AskForMoveCardInBoard"] = (data) => {
  const { cards, cardsPosition, generalNames, playerIds } = data;

  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("../RoomElement/MoveCardInBoardBox.qml");

  const boxCards = [];
  cards.forEach(id => {
    const cardPos = cardsPosition[cards.findIndex(cid => cid === id)];
    const d = lcall("GetCardData", id, playerIds[cardPos]);
    boxCards.push(d);
  });

  const box = roomScene.popupBox.item;
  box.cards = boxCards;
  box.cardsPosition = cardsPosition;
  box.playerIds = playerIds;
  box.generalNames = generalNames.map(name => {
    const namesSplit = name.split('/');
    if (namesSplit.length > 1) {
      return namesSplit.map(nameSplit => luatr(nameSplit)).join('/');
    }
    return luatr(name);
  });

  box.arrangeCards();
  box.accepted.connect(() => {
    replyToServer(box.getResult());
  });
}

callbacks["AskForCardsAndChoice"] = (data) => {
  // jsonData: [ int[] handcards, int[] equips, int[] delayedtricks,
  //  int min, int max, string reason ]
  const { cards, choices, prompt, cancel_choices, min, max, filter_skel, disabled, extra_data } = data;

  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("../RoomElement/ChooseCardsAndChoiceBox.qml");

  const boxCards = [];
  cards.forEach(id => boxCards.push(lcall("GetCardData", id)));

  const box = roomScene.popupBox.item;
  box.cards = boxCards;
  box.ok_options = choices;
  box.prompt = prompt ?? "";
  box.cancel_options = cancel_choices ?? [];
  box.min = min ?? 1;
  box.max = max ?? 1;
  box.disable_cards = disabled ?? [];
  box.filter_skel = filter_skel ?? "";
  box.extra_data = extra_data;

  roomScene.popupBox.moveToCenter();
}

callbacks["MoveCards"] = (moves) => {
  // jsonData: merged moves
  moveCards(moves);
}

// 切换状态 -> 向Lua询问UI情况
// 所以Lua一开始就要设置好各种亮灭的值 而这个自然是通过update
callbacks["PlayCard"] = () => {
  roomScene.activate();
  roomScene.okCancel.visible = true;
}

callbacks["LoseSkill"] = (data) => {
  // jsonData: [ int player_id, string skill_name ]
  const id = data[0];
  const skill_name = data[1];
  const prelight = data[2];
  if (id === Self.id) {
    dashboard.loseSkill(skill_name, prelight);
  }
}

callbacks["AddSkill"] = (data) => {
  // jsonData: [ int player_id, string skill_name ]
  const id = data[0];
  const skill_name = data[1];
  const prelight = data[2];
  if (id === Self.id) {
    dashboard.addSkill(skill_name, prelight);
  }
}

callbacks["PrelightSkill"] = (data) => {
  const skill_name = data[0];
  const prelight = data[1];

  dashboard.prelightSkill(skill_name, prelight);
}

callbacks["AskForUseActiveSkill"] = (data) => {
  // jsonData: string skill_name, string prompt
  const skill_name = data[0];
  const prompt = data[1];
  const cancelable = data[2];
  const extra_data = data[3] ?? {};
  if (prompt === "") {
    roomScene.promptText = luatr("#AskForUseActiveSkill")
      .arg(luatr(skill_name));
  } else {
    roomScene.setPrompt(processPrompt(prompt), true);
  }

  roomScene.activate();
  roomScene.okCancel.visible = true;
}

callbacks["CancelRequest"] = () => {
  roomScene.state = "notactive";
}

callbacks["GameLog"] = (jsonData) => {
  roomScene.addToLog(jsonData)
}

callbacks["AskForUseCard"] = (data) => {
  // jsonData: card, pattern, prompt, cancelable, {}
  const cardname = data[0];
  const pattern = data[1];
  const prompt = data[2];
  const extra_data = data[4];
  const disabledSkillNames = data[5];

  if (prompt === "") {
    roomScene.promptText = luatr("#AskForUseCard")
      .arg(luatr(cardname));
  } else {
    roomScene.setPrompt(processPrompt(prompt), true);
  }
  roomScene.activate();
  roomScene.okCancel.visible = true;
  if (extra_data != null) {
    if ((extra_data.effectTo !== Self.id && // 忽略本轮无懈可击，但目标是自己时不忽略
        roomScene.skippedUseEventId.find(id => id === extra_data.useEventId)) ||
        (config.noSelfNullification && extra_data.effectFrom === Self.id &&
        !lcall("GetCardData", extra_data.effectCardId).multiple_targets)) { // 不对自己使用的单目标锦囊牌无懈
      lcall("UpdateRequestUI", "Button", "Cancel");
      return;
    } else {
      roomScene.extra_data = extra_data;
    }
  }
  // roomScene.responding_card = pattern;
  // disabledSkillNames && (dashboard.disabledSkillNames = disabledSkillNames);
  // roomScene.state = "responding";
  // okButton.enabled = false;
  // cancelButton.enabled = true;
}

callbacks["AskForResponseCard"] = (data) => {
  // jsonData: card_name, pattern, prompt, cancelable, {}
  const cardname = data[0];
  const pattern = data[1];
  const prompt = data[2];
  const disabledSkillNames = data[5];

  if (prompt === "") {
    roomScene.promptText = luatr("#AskForResponseCard")
      .arg(luatr(cardname));
  } else {
    roomScene.setPrompt(processPrompt(prompt), true);
  }
  roomScene.activate();
  roomScene.okCancel.visible = true;
}

const getMarkValue = function(value) {
  if (value instanceof ArrayBuffer) {
    const uint8Array = new Uint8Array(value);
    let result = "";

    for (const byte of uint8Array) {
      // 将字节转换为两位十六进制，并添加\x前缀
      result += `\\x${byte.toString(16).padStart(2, '0')}`;
    }
    return leval(`(function(s) return ToUIString(cbor.decode(s)) end)("${result}")`)
  } else if (!(value instanceof Object)) {
    return value.toString();
  } else {
    return value;
  }
}

callbacks["SetPlayerMark"] = (data) => {
  const player = getPhoto(data[0]);
  const mark = data[1];
  const value = getMarkValue(data[2]);

  let area = mark.startsWith("@!") ? player.picMarkArea : player.markArea;
  if (data[2] === 0) {
    area.removeMark(mark);
  } else {
    area.setMark(mark, mark.startsWith("@@") ? "" : value);
  }
}

callbacks["SetBanner"] = (data) => {
  const mark = data[0];
  const value = getMarkValue(data[1]);
  let area = roomScene.banner;
  if (data[1] === 0) {
    area.removeMark(mark);
  } else {
    area.setMark(mark, mark.startsWith("@@") ? "" : value);
  }
}

callbacks["Animate"] = (data) => {
  // jsonData: [Object object]
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
      const component =
            Qt.createComponent("../RoomElement/SkillInvokeAnimation.qml");
      if (component.status !== Component.Ready)
        return;

      const photo = getPhoto(id);
      if (!photo) {
        return null;
      }

      const animation = component.createObject(photo, {
        skill_name: luatr(data.name),
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
        general: data.deputy ? photo.deputyGeneral : photo.general,
      });
      break;
    }
    default:
      break;
  }
}

callbacks["LogEvent"] = (data) => {
  // jsonData: [Object object]
  switch (data.type) {
    case "Damage": {
      const item = getPhotoOrDashboard(data.to);
      setEmotion(data.to, "damage");
      item.tremble();
      data.damageType = data.damageType || "normal_damage";
      Backend.playSound("./audio/system/" + data.damageType +
                        (data.damageNum > 1 ? "2" : ""));
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
      const tryPlaySound = (general) => {
        if (general) {
          const dat = lcall("GetGeneralData", general);
          const extension = dat.extension;
          const path = SkinBank.getAudio(skill + "_" + general, extension, "skill");
          if (path !== undefined) {
            Backend.playSound(path, data.i);
            return true;
          }
        }
        return false;
      };

      // Try main general first, then deputy general
      if (tryPlaySound(data.general) || tryPlaySound(data.deputy)) {
        break;
      }

      // finally normal skill
      dat = lcall("GetSkillData", skill);
      extension = dat.extension;
      path = SkinBank.getAudio(skill, extension, "skill");
      Backend.playSound(path, data.i);
      break;
    }
    case "PlaySound": {
      const path = SkinBank.getAudioByPath(data.name);
      Backend.playSound(path);
      break;
    }
    case "Death": {
      const item = getPhoto(data.to);
      const extension = lcall("GetGeneralData", item.general).extension;
      const path = SkinBank.getAudio(item.general, extension, "death");
      Backend.playSound(path);
      break;
    }
    default:
      break;
  }
}

callbacks["GameOver"] = (jsonData) => {
  roomScene.state = "notactive";
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("../RoomElement/GameOverBox.qml");
  const box = roomScene.popupBox.item;
  box.winner = jsonData;
  // roomScene.isStarted = false;
}

callbacks["FillAG"] = (data) => {
  const ids = data[0];
  roomScene.manualBox.sourceComponent =
    Qt.createComponent("../RoomElement/AG.qml");
  roomScene.manualBox.item.addIds(ids);
}

callbacks["AskForAG"] = (j) => {
  roomScene.activate();
  roomScene.manualBox.item.interactive = true;
}

callbacks["TakeAG"] = (data) => {
  if (!roomScene.manualBox.item) return;
  const pid = data[0];
  const cid = data[1];
  const item = getPhoto(pid);
  const general = luatr(item.general);

  // the item should be AG box
  roomScene.manualBox.item.takeAG(general, cid);
}

callbacks["CloseAG"] = () => roomScene.manualBox.item.close();

callbacks["CustomDialog"] = (data) => {
  const path = data.path;
  const dat = data.data;
  roomScene.activate();
  roomScene.popupBox.source = AppPath + "/" + path;
  if (dat) {
    roomScene.popupBox.item.loadData(dat);
  }
}

callbacks["MiniGame"] = (data) => {
  const game = data.type;
  const dat = data.data;
  const gdata = lcall("GetMiniGame", game, Self.id, JSON.stringify(dat));
  roomScene.activate();
  roomScene.popupBox.source = AppPath + "/" + gdata.qml_path + ".qml";
  if (dat) {
    roomScene.popupBox.item.loadData(dat);
  }
}

callbacks["UpdateMiniGame"] = (data) => {
  if (roomScene.popupBox.item) {
    roomScene.popupBox.item.updateData(data);
  }
}

callbacks["EmptyRequest"] = (data) => {
  roomScene.activate();
}

callbacks["UpdateLimitSkill"] = (data) => {
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

callbacks["UpdateGameData"] = (data) => {
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
callbacks["ChangeSelf"] = (j) => {
  // move new selfPhoto to dashboard
  let order = new Array(photoModel.count);
  for (let i = 0; i < photoModel.count; i++) {
    const item = photoModel.get(i);
    order[item.seatNumber - 1] = item.id;
    if (item.id === Self.id) {
      dashboard.self = photos.itemAt(i);
    }
  }
  callbacks["ArrangeSeats"](order);

  // update dashboard
  dashboard.update();
}

callbacks["UpdateRequestUI"] = (uiUpdate) => {
  if (uiUpdate["_prompt"])
    roomScene.promptText = processPrompt(uiUpdate["_prompt"]);

  if (uiUpdate._type == "Room") {
    roomScene.applyChange(uiUpdate);
  }
}

// 蒋琬
callbacks["GetPlayerHandcards"] = (data) => {
  const hand = dashboard.handcardArea.cards.map(c => {
    return c.cid;
  })
  replyToServer(hand);
}

callbacks["ReplyToServer"] = (data) => {
  replyToServer(data);
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
