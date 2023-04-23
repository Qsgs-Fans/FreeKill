// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

RowLayout {
  id: root

  property alias self: selfPhoto
  property alias handcardArea: handcardAreaItem
  property alias equipArea: selfPhoto.equipArea
  property alias delayedTrickArea: selfPhoto.delayedTrickArea
  property alias specialArea: selfPhoto.specialArea

  property bool selected: selfPhoto.selected

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

  Photo {
    id: selfPhoto
    Layout.rightMargin: -175 / 8 + (roomArea.width - 175 * 0.75 * 7) / 8
    handcards: handcardAreaItem.length
  }

  Connections {
    target: handcardAreaItem
    function onCardSelected(cardId, selected) {
      dashboard.selectCard(cardId, selected);
    }
  }

  function disableAllCards() {
    handcardAreaItem.enableCards([]);
  }

  function unSelectAll(expectId) {
    handcardAreaItem.unselectAll(expectId);
  }

  function expandPile(pile) {
    let expanded_pile_names = Object.keys(expanded_piles);
    if (expanded_pile_names.indexOf(pile) !== -1)
      return;

    let component = Qt.createComponent("CardItem.qml");
    let parentPos = roomScene.mapFromItem(selfPhoto, 0, 0);

    expanded_piles[pile] = [];
    if (pile === "_equip") {
      let equips = selfPhoto.equipArea.getAllCards();
      equips.forEach(data => {
        data.x = parentPos.x;
        data.y = parentPos.y;
        let card = component.createObject(roomScene, data);
        card.footnoteVisible = true;
        card.footnote = Backend.translate("$Equip");
        handcardAreaItem.add(card);
      })
      handcardAreaItem.updateCardPosition();
    } else {
      let ids = JSON.parse(Backend.callLuaFunction("GetPile", [selfPhoto.playerid, pile]));
      ids.forEach(id => {
        let data = JSON.parse(Backend.callLuaFunction("GetCardData", [id]));
        data.x = parentPos.x;
        data.y = parentPos.y;
        let card = component.createObject(roomScene, data);
        card.footnoteVisible = true;
        card.footnote = Backend.translate(pile);
        handcardAreaItem.add(card);
      });
      handcardAreaItem.updateCardPosition();
    }
  }

  function retractPile(pile) {
    let expanded_pile_names = Object.keys(expanded_piles);
    if (expanded_pile_names.indexOf(pile) === -1)
      return;

    let parentPos = roomScene.mapFromItem(selfPhoto, 0, 0);

    delete expanded_piles[pile];
    if (pile === "_equip") {
      let equips = selfPhoto.equipArea.getAllCards();
      equips.forEach(data => {
        let card = handcardAreaItem.remove([data.cid])[0];
        card.origX = parentPos.x;
        card.origY = parentPos.y;
        card.destroyOnStop();
        card.goBack(true);
      })
      handcardAreaItem.updateCardPosition();
    } else {
      let ids = JSON.parse(Backend.callLuaFunction("GetPile", [selfPhoto.playerid, pile]));
      ids.forEach(id => {
        let card = handcardAreaItem.remove([id])[0];
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
    if (cname) {
      let ids = [], cards = handcardAreaItem.cards;
      for (let i = 0; i < cards.length; i++) {
        if (cardValid(cards[i].cid, cname)) {
          ids.push(cards[i].cid);
        }
      }
      cards = selfPhoto.equipArea.getAllCards();
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
      let pile_data = JSON.parse(Backend.callLuaFunction("GetAllPiles", [selfPhoto.playerid]));
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

    let ids = [], cards = handcardAreaItem.cards;
    for (let i = 0; i < cards.length; i++) {
      if (JSON.parse(Backend.callLuaFunction("CanUseCard", [cards[i].cid, Self.id])))
        ids.push(cards[i].cid);
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

  function updatePending() {
    if (pending_skill === "") return;

    let enabled_cards = [];
    let targets = roomScene.selected_targets;

    handcardAreaItem.cards.forEach((card) => {
      if (card.selected || JSON.parse(Backend.callLuaFunction(
        "ActiveCardFilter",
        [pending_skill, card.cid, pendings, targets]
      )))
        enabled_cards.push(card.cid);
    });

    let cards = selfPhoto.equipArea.getAllCards();
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

    let pile = Backend.callLuaFunction("GetExpandPileOfSkill", [pending_skill]);
    let pile_ids = JSON.parse(Backend.callLuaFunction("GetPile", [selfPhoto.playerid, pile]));
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
    for (let i = 0; i < skillButtons.count; i++) {
      let item = skillButtons.itemAt(i);
      item.enabled = item.pressed;
    }

    updatePending();
  }

  function deactivateSkillButton() {
    for (let i = 0; i < skillButtons.count; i++) {
      skillButtons.itemAt(i).pressed = false;
    }
  }

  function stopPending() {
    pending_skill = "";
    pending_card = -1;

    retractAllPiles();

    pendings = [];
    handcardAreaItem.adjustCards();
    handcardAreaItem.unselectAll();
    cardSelected(-1);
  }

  function addSkill(skill_name, prelight) {
    skillPanel.addSkill(skill_name, prelight);
  }

  function loseSkill(skill_name, prelight) {
    skillPanel.loseSkill(skill_name, prelight);
  }

  function prelightSkill(skill_name, prelight) {
    let btns = skillPanel.prelight_buttons;
    for (let i = 0; i < btns.count; i++) {
      let btn = btns.itemAt(i);
      if (btn.orig === skill_name) {
        btn.prelighted = prelight;
        btn.enabled = true;
      }
    }
  }

  function enableSkills(cname) {
    if (cname) {
      // if cname is presented, we are responding use or play.
      for (let i = 0; i < skillButtons.count; i++) {
        let item = skillButtons.itemAt(i);
        let fitpattern = JSON.parse(Backend.callLuaFunction("SkillFitPattern", [item.orig, cname]));
        let canresp = JSON.parse(Backend.callLuaFunction("SkillCanResponse", [item.orig]));
        item.enabled = fitpattern && canresp;
      }
      return;
    }
    for (let i = 0; i < skillButtons.count; i++) {
      let item = skillButtons.itemAt(i);
      item.enabled = JSON.parse(Backend.callLuaFunction("ActiveCanUse", [item.orig]));
    }
  }

  function disableSkills() {
    for (let i = 0; i < skillButtons.count; i++)
      skillButtons.itemAt(i).enabled = false;
  }

  function tremble() {
    selfPhoto.tremble();
  }
}
