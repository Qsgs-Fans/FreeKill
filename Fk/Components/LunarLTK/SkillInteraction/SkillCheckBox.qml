// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Components.Common

MetroButton {
  id: root
  property string skill
  property var choices: []
  property var all_choices: []
  property int min_num: 0
  property int max_num: 0
  property var answer: []
  property bool detailed: false
  property bool cancelable: false

  text: Lua.tr("AskForChoices")

  onAnswerChanged: {
    if (!answer) return;
    Lua.call("UpdateRequestUI", "Interaction", "1", "update", answer);
  }

  onClicked: {
    Lua.call("UpdateRequestUI", "Interaction", "1", "update", []);
    if (detailed) {
      roomScene.popupBox.sourceComponent =
        Qt.createComponent("../../../Pages/LunarLTK/DetailedCheckBox.qml");
    } else {
      roomScene.popupBox.sourceComponent =
        Qt.createComponent("../../../Pages/LunarLTK/CheckBox.qml");
    }
    const box = roomScene.popupBox.item;
    box.options = choices;
    box.all_options = all_choices;
    box.skill_name = skill;
    box.min_num = min_num;
    box.max_num = max_num;
    box.accepted.connect(() => {
      answer = box.result.map(result => all_choices[result]);
    });
  }

}
