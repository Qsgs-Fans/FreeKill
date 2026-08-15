// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import LunarLtk

RowLayout {
  id: root

  required property DashboardModel dataModel

  property alias handcardArea: handcardAreaItem
  property alias sortable: handcardAreaItem.sortable

  signal cardSelected(var card)

  Item {
    Layout.preferredWidth: 5
  }

  HandcardArea {
    id: handcardAreaItem
    Layout.fillWidth: true
    Layout.preferredHeight: 130
    Layout.alignment: Qt.AlignBottom
    Layout.bottomMargin: 24
    onWidthChanged: updateCardPosition(true);

    dataModel: root.dataModel
  }

  SkillArea {
    id: skillArea
    Layout.fillHeight: true
    Layout.fillWidth: true
    Layout.maximumWidth: width
    Layout.maximumHeight: height
    Layout.alignment: Qt.AlignBottom
    Layout.bottomMargin: 32
    Layout.rightMargin: -16

    dataModel: root.dataModel
  }

  Item {
    Layout.preferredWidth: 175
    Layout.preferredHeight: 233
    Layout.rightMargin: -175 / 8 + (roomArea.width - 175 * 0.75 * 7) / 8
  }

  Connections {
    target: root.dataModel
    function onSelfChanged() {
      root.handcardArea.syncCards();
    }
  }

  function disableAllCards() {
    handcardAreaItem.enableCards([]);
  }

  function prelightSkill(skill_name, prelight) {
    // const btns = skillArea.prelight_buttons;
    // for (let i = 0; i < btns.count; i++) {
    //   const btn = btns.itemAt(i);
    //   if (btn.orig === skill_name) {
    //     btn.prelighted = prelight;
    //     btn.enabled = true;
    //   }
    // }
  }

  function updateHandcards() {
    Lua.selfPlayer.filterHandcards();
    handcardAreaItem.cards.forEach(v => {
      v.setData(Ltk.getCardData(v.cid, true));
    });
  }

  function applyChange(uiUpdate) {
    dataModel.applyChange(uiUpdate);
    handcardAreaItem.applyChange(uiUpdate);
  }

  function clearVisiblePile() {
    if (dataModel?.visible_ids) dataModel.visible_ids = [];
  }
}
