// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick

// https://gist.github.com/jonmcclung/bae669101d17b103e94790341301c129
// modified some code
ListView {
  function show(text, duration) {
    if (duration === undefined) {
      duration = 3000;
    }
    model.insert(0, {text: text, duration: duration, listmodel: listmodel});
  }

  id: root
  clip: true

  z: Infinity
  spacing: 5
  anchors.fill: parent
  anchors.bottomMargin: 10
  verticalLayoutDirection: ListView.BottomToTop

  interactive: false

  displaced: Transition {
    NumberAnimation {
      properties: "y"
      easing.type: Easing.InOutQuad
    }
  }

  delegate: Toast {
    required property string text
    required property real duration
    required property int index
    required property var listmodel

    onFinish: {
      listmodel.remove(index);
    }

    Component.onCompleted: {
      show(text, duration);
    }
  }

  model: ListModel {id: listmodel}
}
