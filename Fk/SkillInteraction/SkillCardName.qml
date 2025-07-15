// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Pages

MetroButton {
  id: root
  property string skill
  property var extra_data
  property var choices : (extra_data !== undefined) ? extra_data.choices : []
  property var all_choices : (extra_data !== undefined) ? extra_data.all_choices : []
  property string default_choice : (extra_data !== undefined) ? extra_data.default_choice : ""
  property string answer: default_choice

  text: Util.processPrompt(answer)

  onAnswerChanged: {
    if (!answer) return;
    lcall("UpdateRequestUI", "Interaction", "1", "update", answer);
    // lcall("SetInteractionDataOfSkill", skill, JSON.stringify(answer));
    // roomScene.dashboard.startPending(skill);
  }

  onClicked: {
    roomScene.popupBox.sourceComponent =
      Qt.createComponent(AppPath + "/packages/utility/qml/CardNamesBox.qml");

    const box = roomScene.popupBox.item;
    box.all_names = all_choices;
    box.card_names = choices;
    box.prompt = skill;
    box.accepted.connect(() => {
      answer = box.result;
    });
  }

}
