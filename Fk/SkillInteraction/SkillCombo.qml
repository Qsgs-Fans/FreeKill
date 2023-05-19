// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk.Pages

MetroButton {
  id: root
  property string skill
  property var choices: []
  property string default_choice
  property string answer: default_choice
  text: Backend.translate(answer)

  onAnswerChanged: {
    if (!answer) return;
    Backend.callLuaFunction(
      "SetInteractionDataOfSkill",
      [skill, JSON.stringify(answer)]
    );
    roomScene.dashboard.startPending(skill);
  }

  onClicked: {
    roomScene.popupBox.sourceComponent = Qt.createComponent("Fk.RoomElement", "ChoiceBox");
    let box = roomScene.popupBox.item;
    box.options = choices;
    box.accepted.connect(() => {
      answer = choices[box.result];
    });
  }

}
