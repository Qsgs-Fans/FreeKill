// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Models.Popups

pragma ComponentBehavior: Bound

MetroButton {
  id: root

  property ChoicesModel dataModel

  property string answer: dataModel?.result[0] ?? ""

  Connections {
    target: dataModel
    function onAccepted() {
      answer = dataModel.result[0];
      roomScene.popupItem?.finished();
    }
  }

  text: Ltk.processPrompt(answer)

  onAnswerChanged: {
    if (!answer) return;
    Lua.updateRequestUI("Interaction", "1", "update", answer);
  }

  onClicked: {
    if (!dataModel.cancelable && !dataModel.detailed && dataModel.choices.length < 2) return;
    roomScene.showPopup(Qt.createComponent("LunarLtk.Pages.Popups", "ChoicesBox"), { dataModel, noOneLine: true });
  }
}
