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
  property bool sortable: true
  property var pending_card
  property var pendings: [] // int[], store cid
  property int selected_card: -1

  property alias skillButtons: skillPanel.skill_buttons
  property alias notActiveButtons: skillPanel.not_active_buttons

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
      lcall("UpdateRequestUI", "CardItem", cardId, "click", { selected, autoTarget: config.autoTarget } );
    }
    function onCardDoubleClicked(cardId, selected) {
      lcall("UpdateRequestUI", "CardItem", cardId, "doubleClick", { selected, doubleClickUse: config.doubleClickUse, autoTarget: config.autoTarget } );
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

  function deactivateSkillButton() {
    for (let i = 0; i < skillButtons.count; i++) {
      let item = skillButtons.itemAt(i);
      item.pressed = false;
    }
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
    sortable = handcardAreaItem.sortable;

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

    const skills = lcall("GetMySkills");
    for (let s of skills) {
      addSkill(s);
    }

    cards = roomScene.drawPile.remove(lcall("GetPlayerHandcards", Self.id));
    handcardAreaItem.add(cards);
  }

  function applyChange(uiUpdate) {
    // TODO: 先确定要不要展开相关Pile
    // card - HandcardArea
    const parentPos = roomScene.mapFromItem(self, 0, 0);
    const component = Qt.createComponent("../RoomElement/CardItem.qml");

    uiUpdate["_delete"]?.forEach(data => {
      if (data.type == "CardItem") {
        const card = handcardAreaItem.remove([data.id])[0];
        card.origX = parentPos.x;
        card.origY = parentPos.y;
        card.destroyOnStop();
        card.goBack(true);
      }
    });
    uiUpdate["_new"]?.forEach(dat => {
      if (dat.type == "CardItem") {
        const data = lcall("GetCardData", dat.data.id);
        data.x = parentPos.x;
        data.y = parentPos.y;
        const card = component.createObject(roomScene, data);
        card.footnoteVisible = true;
        card.markVisible = false;
        card.footnote = luatr(dat.ui_data.footnote);
        handcardAreaItem.add(card);
      }
    });
    handcardAreaItem.applyChange(uiUpdate);
    sortable = handcardAreaItem.sortable;
    // skillBtn - SkillArea
    const skDatas = uiUpdate["SkillButton"]
    skDatas?.forEach(skdata => {
      for (let i = 0; i < skillButtons.count; i++) {
        const skillBtn = skillButtons.itemAt(i);
        if (skillBtn.orig == skdata.id) {
          skillBtn.enabled = skdata.enabled;
          skillBtn.pressed = skdata.selected;
          break;
        }
      }
    });

    pending_skill = lcall("GetPendingSkill");
  }
}
