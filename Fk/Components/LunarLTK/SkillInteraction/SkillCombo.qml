// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Components.Common

MetroButton {
  id: root
  property string skill
  property var choices: []
  property var all_choices: []
  property string default_choice
  property string answer: default_choice
  property bool detailed: false

  text: Util.processPrompt(answer)

  onAnswerChanged: {
    if (!answer) return;
    Lua.call("UpdateRequestUI", "Interaction", "1", "update", answer);
  }

  onClicked: {
    if (all_choices.length < 2) return;
    if (detailed) {
      roomScene.popupBox.sourceComponent =
        Qt.createComponent("../../../Pages/LunarLTK/DetailedChoiceBox.qml");
    } else {
      roomScene.popupBox.sourceComponent =
        Qt.createComponent("../../../Pages/LunarLTK/ChoiceBox.qml");
    }
    const box = roomScene.popupBox.item;
    box.options = choices;
    box.all_options = all_choices;
    box.skill_name = skill;
    box.accepted.connect(() => {
      answer = all_choices[box.result];
    });
  }

}
