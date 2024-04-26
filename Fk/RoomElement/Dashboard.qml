// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Fk

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
  property var extra_cards: []

  property var disabledSkillNames: []

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

  function expandPile(pile, extra_ids, extra_footnote) {
    const expanded_pile_names = Object.keys(expanded_piles);
    if (expanded_pile_names.indexOf(pile) !== -1)
      return;

    const component = Qt.createComponent("../RoomElement/CardItem.qml");
    const parentPos = roomScene.mapFromItem(self, 0, 0);

    expanded_piles[pile] = [];
    let ids, footnote;
    if (pile === "_equip") {
      ids = self.equipArea.getAllCards().map(e => e.cid);
      footnote = "$Equip";
    } else if (pile === "_extra") {
      ids = extra_ids;
      extra_cards = ids;
      footnote = extra_footnote;
    } else {
      ids = lcall("GetPile", self.playerid, pile);
      footnote = pile;
    }
    ids.forEach(id => {
      const data = lcall("GetCardData", id);
      data.x = parentPos.x;
      data.y = parentPos.y;
      const card = component.createObject(roomScene, data);
      card.footnoteVisible = true;
      card.footnote = luatr(footnote);
      handcardAreaItem.add(card);
    });
    handcardAreaItem.updateCardPosition();
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
      let ids = [];
      if (pile === "_extra") {
        ids = extra_cards;
        extra_cards = [];
      } else {
        ids = lcall("GetPile", self.playerid, pile);
      }
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
      let ret = lcall("CardFitPattern", cid, cname);

      if (ret) {
        if (roomScene.respond_play) {
          ret = ret && !lcall("CardProhibitedResponse", cid);
        } else {
          ret = ret && !lcall("CardProhibitedUse", cid);
        }
      }

      return ret;
    }

    const pile_data = lcall("GetAllPiles", self.playerid);
    extractWoodenOx();

    const handleMethod = roomScene.respond_play ? "response" : "use";
    if (cname) {
      const ids = [];
      let cards = handcardAreaItem.cards;
      for (let i = 0; i < cards.length; i++) {
        cards[i].prohibitReason = "";
        if (cardValid(cards[i].cid, cname)) {
          ids.push(cards[i].cid);
        } else {
          const prohibitReason = lcall("GetCardProhibitReason", cards[i].cid,
                                       handleMethod, cname);
          if (prohibitReason) {
            cards[i].prohibitReason = prohibitReason;
          }
        }
      }
      cards = self.equipArea.getAllCards();
      cards.forEach(c => {
        c.prohibitReason = "";
        if (cardValid(c.cid, cname)) {
          ids.push(c.cid);
          if (!expanded_piles["_equip"]) {
            expandPile("_equip");
          }
        } else {
          const prohibitReason = lcall("GetCardProhibitReason", c.cid,
                                       handleMethod, cname);
          if (prohibitReason) {
            c.prohibitReason = prohibitReason;
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
      cards[i].prohibitReason = "";
      if (lcall("CanUseCard", cards[i].cid, Self.id,
                JSON.stringify(roomScene.extra_data))) {
        ids.push(cards[i].cid);
      } else {
        // cannot use? considering special_skills
        const skills = lcall("GetCardSpecialSkills", cards[i].cid);
        for (let j = 0; j < skills.length; j++) {
          const s = skills[j];
          if (lcall("ActiveCanUse", s, JSON.stringify(roomScene.extra_data))) {
            ids.push(cards[i].cid);
            break;
          }
        }

        // still cannot use? show message on card
        if (!ids.includes(cards[i].cid)) {
          const prohibitReason = lcall("GetCardProhibitReason", cards[i].cid,
                                       "play");
          if (prohibitReason) {
            cards[i].prohibitReason = prohibitReason;
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
        roomScene.resetPrompt();
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

  function extractWoodenOx() {
    const pile_data = lcall("GetAllPiles", self.playerid);
    if (!roomScene.autoPending) {
      // 先屏蔽AskForUseActiveSkill再说，这下只剩使用打出以及出牌阶段了
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

    handcardAreaItem.cards.forEach((card) => {
      if (card.selected || lcall("ActiveCardFilter", pending_skill, card.cid,
                                 pendings, targets))
        enabled_cards.push(card.cid);
    });

    const cards = self.equipArea.getAllCards();
    cards.forEach(c => {
      if (lcall("ActiveCardFilter", pending_skill, c.cid, pendings, targets)) {
        enabled_cards.push(c.cid);
        if (!expanded_piles["_equip"]) {
          expandPile("_equip");
        }
      }
    })

    let pile = lcall("GetExpandPileOfSkill", pending_skill);
    let pile_ids = pile;
    if (typeof pile === "string") {
      pile_ids = lcall("GetPile", self.playerid, pile);
    } else {
      pile = "_extra";
    }

    pile_ids.forEach(cid => {
      if (lcall("ActiveCardFilter", pending_skill, cid, pendings, targets)) {
        enabled_cards.push(cid);
      };
      if (!expanded_piles[pile]) {
        expandPile(pile, pile_ids, pending_skill);
      }
    });

    handcardAreaItem.enableCards(enabled_cards);

    if (lcall("CanViewAs", pending_skill, pendings)) {
      pending_card = {
        skill: pending_skill,
        subcards: pendings
      };
      cardSelected(JSON.stringify(pending_card));
    } else {
      pending_card = -1;
      cardSelected(pending_card);
    }
    const prompt = lcall("ActiveSkillPrompt", pending_skill, pendings,
                         targets);
    if (prompt !== "") {
      roomScene.setPrompt(Util.processPrompt(prompt));
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

    const cards = handcardAreaItem.cards;
    for (let i = 0; i < cards.length; i++) {
      cards[i].prohibitReason = "";
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
        if (disabledSkillNames.includes(item.orig)) {
          item.enabled = false;
          continue;
        }

        const fitpattern = lcall("SkillFitPattern", item.orig, cname);
        const canresp = lcall("SkillCanResponse", item.orig, cardResponsing);
        item.enabled = fitpattern && canresp;
      }
      return;
    }
    for (let i = 0; i < skillButtons.count; i++) {
      const item = skillButtons.itemAt(i);
      if (disabledSkillNames.includes(item.orig)) {
        item.enabled = false;
        continue;
      }

      item.enabled = lcall("ActiveCanUse", item.orig,
                           JSON.stringify(roomScene.extra_data));
    }
  }

  function disableSkills() {
    disabledSkillNames = [];
    for (let i = 0; i < skillButtons.count; i++)
      skillButtons.itemAt(i).enabled = false;
  }

  function tremble() {
    self.tremble();
  }

  function updateHandcards() {
    lcall("FilterMyHandcards");
    handcardAreaItem.cards.forEach(v => {
      v.setData(lcall("GetCardData", v.cid));
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

    const skills = lcall("GetPlayerSkills", Self.id);
    for (let s of skills) {
      addSkill(s.name);
    }

    cards = roomScene.drawPile.remove(lcall("GetPlayerHandcards", Self.id));
    handcardAreaItem.add(cards);
  }
}
