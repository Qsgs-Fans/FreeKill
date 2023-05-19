// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk

Item {
  id: root
  property string skill_type
  property string skill_name
  signal finished()

  PixmapAnimation {
    id: typeAnim
    anchors.centerIn: parent
    source: SkinBank.PIXANIM_DIR + "skillInvoke/" + skill_type
    keepAtStop: true
  }

  Text {
    id: bigSkillName
    anchors.centerIn: parent
    anchors.horizontalCenterOffset: 100
    text: skill_name
    font.pixelSize: Math.max(24, 48 - (text.length - 2) * 6)
    font.family: fontLi2.name
    style: Text.Outline
    color: "white"
    opacity: 0
  }

  ParallelAnimation {
    id: textAnim
    PropertyAnimation {
      target: bigSkillName
      property: "opacity"
      to: 1
      easing.type: Easing.InQuart
      duration: 200
    }

    PropertyAnimation {
      target: bigSkillName
      property: "anchors.horizontalCenterOffset"
      to: 0
      easing.type: Easing.InQuad
      duration: 240
    }

    onFinished: {
      pauseAnim.start();
    }
  }

  SequentialAnimation {
    id: pauseAnim

    PauseAnimation {
      duration: 1200
    }

    PropertyAnimation {
      target: root
      property: "opacity"
      to: 0
      duration: 200
      easing.type: Easing.OutQuart
    }
    onFinished: {
      root.visible = false;
      root.finished();
    }
  }

  Component.onCompleted: {
    typeAnim.start();
    textAnim.start();
  }
}
