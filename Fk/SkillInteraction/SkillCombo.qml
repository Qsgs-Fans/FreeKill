// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Pages

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
    lcall("SetInteractionDataOfSkill", skill, JSON.stringify(answer));
    roomScene.dashboard.startPending(skill);
  }

  onClicked: {
    if (detailed) {
      roomScene.popupBox.sourceComponent =
        Qt.createComponent("../RoomElement/DetailedChoiceBox.qml");
    } else {
      roomScene.popupBox.sourceComponent =
        Qt.createComponent("../RoomElement/ChoiceBox.qml");
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
