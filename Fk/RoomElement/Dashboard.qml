// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

RowLayout {
  id: root

  property var self
  property alias handcardArea: handcardAreaItem

  property string pending_skill: ""
  property var pending_card
  property var pendings: [] // int[], store cid
  property int selected_card: -1

  property alias skillButtons: skillPanel.skill_buttons

  property var expanded_piles: ({}) // name -> int[]

  signal cardSelected(var card)

  Item { width: 5 }

  HandcardArea {
    id: handcardAreaItem
    Layout.fillWidth: true
    Layout.preferredHeight: 130
    Layout.alignment: Qt.AlignBottom
    Layout.bottomMargin: 24
    onWidthChanged: updateCardPosition(true);
  }

  SkillArea {
    Layout.fillHeight: true
    Layout.fillWidth: true
    Layout.maximumWidth: width
    Layout.maximumHeight: height
    Layout.alignment: Qt.AlignBottom
    Layout.bottomMargin: 32
    Layout.rightMargin: -16
    id: skillPanel
  }

  Item {
    width: 175
    height: 233
    Layout.rightMargin: -175 / 8 + (roomArea.width - 175 * 0.75 * 7) / 8
    // handcards: handcardAreaItem.length
  }

  Connections {
    target: handcardAreaItem
    function onCardSelected(cardId, selected) {
      dashboard.selectCard(cardId, selected);
    }
    function onLengthChanged() {
      self.handcards = handcardAreaItem.length;
    }
  }

  function disableAllCards() {
    handcardAreaItem.enableCards([]);
  }

  function unSelectAll(expectId) {
    handcardAreaItem.unselectAll(expectId);
  }

  function expandPile(pile) {
    const expanded_pile_names = Object.keys(expanded_piles);
    if (expanded_pile_names.indexOf(pile) !== -1)
      return;

    const component = Qt.createComponent("../RoomElement/CardItem.qml");
    const parentPos = roomScene.mapFromItem(self, 0, 0);

    expanded_piles[pile] = [];
    if (pile === "_equip") {
      const equips = self.equipArea.getAllCards();
      equips.forEach(data => {
        data.x = parentPos.x;
        data.y = parentPos.y;
        const card = component.createObject(roomScene, data);
        card.footnoteVisible = true;
        card.footnote = Backend.translate("$Equip");
        handcardAreaItem.add(card);
      })
      handcardAreaItem.updateCardPosition();
    } else {
      const ids = JSON.parse(Backend.callLuaFunction("GetPile", [self.playerid, pile]));
      ids.forEach(id => {
        const data = JSON.parse(Backend.callLuaFunction("GetCardData", [id]));
        data.x = parentPos.x;
        data.y = parentPos.y;
        const card = component.createObject(roomScene, data);
        card.footnoteVisible = true;
        card.footnote = Backend.translate(pile);
        handcardAreaItem.add(card);
      });
      handcardAreaItem.updateCardPosition();
    }
  }

  function retractPile(pile) {
    const expanded_pile_names = Object.keys(expanded_piles);
    if (expanded_pile_names.indexOf(pile) === -1)
      return;

    const parentPos = roomScene.mapFromItem(self, 0, 0);

    delete expanded_piles[pile];
    if (pile === "_equip") {
      const equips = self.equipArea.getAllCards();
      equips.forEach(data => {
        const card = handcardAreaItem.remove([data.cid])[0];
        card.origX = parentPos.x;
        card.origY = parentPos.y;
        card.destroyOnStop();
        card.goBack(true);
      })
      handcardAreaItem.updateCardPosition();
    } else {
      const ids = JSON.parse(Backend.callLuaFunction("GetPile", [self.playerid, pile]));
      ids.forEach(id => {
        const card = handcardAreaItem.remove([id])[0];
        card.origX = parentPos.x;
        card.origY = parentPos.y;
        card.destroyOnStop();
        card.goBack(true);
      });
      handcardAreaItem.updateCardPosition();
    }
  }

  function retractAllPiles() {
    for (let key in expanded_piles) {
      retractPile(key);
    }
  }

  // If cname is set, we are responding card.
  function enableCards(cname) {
    const cardValid = (cid, cname) => {
      let ret = JSON.parse(Backend.callLuaFunction(
        "CardFitPattern", [cid, cname]));

      if (ret) {
        if (roomScene.respond_play) {
          ret = ret && !JSON.parse(Backend.callLuaFunction(
            "CardProhibitedResponse", [cid]));
        } else {
          ret = ret && !JSON.parse(Backend.callLuaFunction(
            "CardProhibitedUse", [cid]));
        }
      }

      return ret;
    }

    const pile_data = JSON.parse(Backend.callLuaFunction("GetAllPiles", [self.playerid]));
    extractWoodenOx();

    if (cname) {
      const ids = [];
      let cards = handcardAreaItem.cards;
      for (let i = 0; i < cards.length; i++) {
        if (cardValid(cards[i].cid, cname)) {
          ids.push(cards[i].cid);
        }
      }
      cards = self.equipArea.getAllCards();
      cards.forEach(c => {
        if (cardValid(c.cid, cname)) {
          ids.push(c.cid);
          if (!expanded_piles["_equip"]) {
            expandPile("_equip");
          }
        }
      });

      // Must manually analyze pattern here
      let pile_list = cname.split("|")[4];
      if (pile_list && pile_list !== "." && !(pile_data instanceof Array)) {
        pile_list = pile_list.split(",");
        for (let pile_name of pile_list) {
          pile_data[pile_name] && pile_data[pile_name].forEach(cid => {
            if (cardValid(cid, cname)) {
              ids.push(cid);
              if (!expanded_piles[pile_name]) {
                expandPile(pile_name);
              }
            }
          });
        }
      }

      handcardAreaItem.enableCards(ids);
      return;
    }

    const ids = [], cards = handcardAreaItem.cards;
    for (let i = 0; i < cards.length; i++) {
      if (JSON.parse(Backend.callLuaFunction("CanUseCard", [cards[i].cid, Self.id]))) {
        ids.push(cards[i].cid);
      } else {
        // cannot use? considering special_skills
        const skills = JSON.parse(Backend.callLuaFunction("GetCardSpecialSkills", [cards[i].cid]));
        for (let j = 0; j < skills.length; j++) {
          const s = skills[j];
          if (JSON.parse(Backend.callLuaFunction("ActiveCanUse", [s]))) {
            ids.push(cards[i].cid);
            break;
          }
        }
      }
    }
    handcardAreaItem.enableCards(ids)
    if (pending_skill === "") {
      cancelButton.enabled = false;
    }
  }

  function selectCard(cardId, selected) {
    if (pending_skill !== "") {
      if (selected) {
        pendings.push(cardId);
      } else {
        pendings.splice(pendings.indexOf(cardId), 1);
      }

      updatePending();
    } else {
      if (selected) {
        handcardAreaItem.unselectAll(cardId);
        selected_card = cardId;
      } else {
        handcardAreaItem.unselectAll();
        selected_card = -1;
      }
      cardSelected(selected_card);
    }
  }

  function revertSelection() {
    if (pending_skill !== "") {
      let to_select_cards = handcardAreaItem.cards.filter(cd => {
        if (pendings.indexOf(cd.cid) === -1) {
          return true;
        } else {
          cd.selected = !cd.selected;
          cd.clicked();
        }
      });

      to_select_cards.forEach(cd => {
        if (cd.selectable) {
          cd.selected = !cd.selected;
          cd.clicked();
        }
      });
    }
  }

  function getSelectedCard() {
    if (pending_skill !== "") {
      return JSON.stringify({
        skill: pending_skill,
        subcards: pendings
      });
    } else {
      return selected_card;
    }
  }

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

  function extractWoodenOx() {
    const pile_data = JSON.parse(Backend.callLuaFunction("GetAllPiles", [self.playerid]));
    if (!roomScene.autoPending) { // 先屏蔽AskForUseActiveSkill再说，这下只剩使用打出以及出牌阶段了
      for (let name in pile_data) {
        if (name.endsWith("&")) expandPile(name);
      }
    }
  }

  function updatePending() {
    roomScene.resetPrompt();
    if (pending_skill === "") return;

    const enabled_cards = [];
    const targets = roomScene.selected_targets;
    const prompt = JSON.parse(Backend.callLuaFunction(
      "ActiveSkillPrompt",
      [pending_skill, pendings, targets]
    ));
    if (prompt !== "") {
      roomScene.setPrompt(processPrompt(prompt));
    }

    handcardAreaItem.cards.forEach((card) => {
      if (card.selected || JSON.parse(Backend.callLuaFunction(
        "ActiveCardFilter",
        [pending_skill, card.cid, pendings, targets]
      )))
        enabled_cards.push(card.cid);
    });

    const cards = self.equipArea.getAllCards();
    cards.forEach(c => {
      if (JSON.parse(Backend.callLuaFunction(
        "ActiveCardFilter",
        [pending_skill, c.cid, pendings, targets]
      ))) {
        enabled_cards.push(c.cid);
        if (!expanded_piles["_equip"]) {
          expandPile("_equip");
        }
      }
    })

    const pile = Backend.callLuaFunction("GetExpandPileOfSkill", [pending_skill]);
    const pile_ids = JSON.parse(Backend.callLuaFunction("GetPile", [self.playerid, pile]));
    pile_ids.forEach(cid => {
      if (JSON.parse(Backend.callLuaFunction(
        "ActiveCardFilter",
        [pending_skill, cid, pendings, targets]
      ))) {
        enabled_cards.push(cid);
        if (!expanded_piles[pile]) {
          expandPile(pile);
        }
      }
    });

    handcardAreaItem.enableCards(enabled_cards);

    if (JSON.parse(Backend.callLuaFunction(
        "CanViewAs",
        [pending_skill, pendings]
      ))) {
      pending_card = {
        skill: pending_skill,
        subcards: pendings
      };
      cardSelected(JSON.stringify(pending_card));
    } else {
      pending_card = -1;
      cardSelected(pending_card);
    }
  }

  function startPending(skill_name) {
    pending_skill = skill_name;
    pendings = [];
    handcardAreaItem.unselectAll();
    retractAllPiles();

    for (let i = 0; i < skillButtons.count; i++) {
      const item = skillButtons.itemAt(i);
      item.enabled = item.pressed;
    }

    updatePending();
  }

  function deactivateSkillButton() {
    for (let i = 0; i < skillButtons.count; i++) {
      let item = skillButtons.itemAt(i);
      item.pressed = false;
    }
  }

  function stopPending() {
    pending_skill = "";
    pending_card = -1;

    retractAllPiles();

    if (roomScene.state == "playing")
      extractWoodenOx();

    pendings = [];
    handcardAreaItem.adjustCards();
    handcardAreaItem.unselectAll();
    cardSelected(-1);
    roomScene.resetPrompt();
  }

  function addSkill(skill_name, prelight) {
    skillPanel.addSkill(skill_name, prelight);
  }

  function loseSkill(skill_name, prelight) {
    skillPanel.loseSkill(skill_name, prelight);
  }

  function prelightSkill(skill_name, prelight) {
    const btns = skillPanel.prelight_buttons;
    for (let i = 0; i < btns.count; i++) {
      const btn = btns.itemAt(i);
      if (btn.orig === skill_name) {
        btn.prelighted = prelight;
        btn.enabled = true;
      }
    }
  }

  function enableSkills(cname, cardResponsing) {
    if (cname) {
      // if cname is presented, we are responding use or play.
      for (let i = 0; i < skillButtons.count; i++) {
        const item = skillButtons.itemAt(i);
        const fitpattern = JSON.parse(Backend.callLuaFunction("SkillFitPattern", [item.orig, cname]));
        const canresp = JSON.parse(Backend.callLuaFunction("SkillCanResponse", [item.orig, cardResponsing]));
        item.enabled = fitpattern && canresp;
      }
      return;
    }
    for (let i = 0; i < skillButtons.count; i++) {
      const item = skillButtons.itemAt(i);
      item.enabled = JSON.parse(Backend.callLuaFunction("ActiveCanUse", [item.orig]));
    }
  }

  function disableSkills() {
    for (let i = 0; i < skillButtons.count; i++)
      skillButtons.itemAt(i).enabled = false;
  }

  function tremble() {
    self.tremble();
  }

  function updateHandcards() {
    Backend.callLuaFunction("FilterMyHandcards", []);
    handcardAreaItem.cards.forEach(v => {
      const data = JSON.parse(Backend.callLuaFunction("GetCardData", [v.cid]));
      v.setData(data);
    });
  }

  function update() {
    unSelectAll();
    disableSkills();

    let cards = handcardAreaItem.cards;
    const toRemove = [];
    for (let c of cards) {
      toRemove.push(c.cid);
      c.origY += 30;
      c.origOpacity = 0
      c.goBack(true);
      c.destroyOnStop();
    }
    handcardAreaItem.remove(toRemove);

    skillPanel.clearSkills();

    const skills = JSON.parse(Backend.callLuaFunction("GetPlayerSkills", [Self.id]));
    for (let s of skills) {
      addSkill(s.name);
    }

    cards = roomScene.drawPile.remove(JSON.parse(Backend.callLuaFunction("GetPlayerHandcards", [Self.id])));
    handcardAreaItem.add(cards);
  }
}
