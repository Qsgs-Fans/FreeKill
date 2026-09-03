import QtQuick
import Qt5Compat.GraphicalEffects

import Fk
import Fk.Components.Common
import Fk.Components.GameCommon
import LunarLtk

Item {
  id: root
  anchors.fill: parent

  property var bgColor: "gray"
  property var contentAreaColor: "transparent"
  property real contentAreaSize: 0.6
  property string textSource: ""
  property string mediaSource: ""
  property int pauseTime: 2000
  property int fadeTime: 500

  Rectangle {
    id: contentArea
    width: parent.width * contentAreaSize
    height: parent.height * contentAreaSize
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    opacity: 0
    color: root.contentAreaColor
    radius: Math.max(width, height) / 2
    clip: true

    layer.enabled: true
    layer.effect: DropShadow {
      transparentBorder: true
      radius: 24
      samples: 32
      color: "#99000000"
    }

    MediaArea {
      id: media
      source: mediaSource !== "" ? Cpp.path + "/" + mediaSource : ""
      visible: mediaSource !== ""
      anchors.fill: parent
      fillMode: Image.PreserveAspectFit
      pause: false
      opacity: 0
    }

    GlowText {
      id: text
      anchors.centerIn: parent
      text: Ltk.processPrompt(textSource) // 不用这个都可以直接放到Fk里了
      visible: textSource !== ""
      font.family: Config.libianName
      font.pixelSize: 36
      font.bold: true
      color: "#FEFEFE"
      glow.color: '#a16d35'
      glow.spread: 0.8
      opacity: 0
    }
  }

  Rectangle {
    id: bg
    anchors.fill: parent
    color: bgColor
    z: -1
    opacity: 0
  }

  SequentialAnimation {
    id: anim
    running: false

    ParallelAnimation {
      NumberAnimation {
        targets: [ bg, contentArea, media, text ]
        property: "opacity"
        to: 0.8
        duration: fadeTime
      }
    }

    PauseAnimation {
      duration: pauseTime
    }

    ParallelAnimation {
      NumberAnimation {
        targets: [ bg, contentArea, media, text ]
        property: "opacity"
        to: 0
        duration: fadeTime
      }
    }

    onFinished: {
      roomScene.bigAnim.source = "";
    }
  }

  function loadData(data) {
    bgColor = data.bgColor ?? "gray";
    contentAreaColor = data.contentAreaColor ?? "transparent";
    contentAreaSize = data.contentAreaSize ?? 0.6;
    textSource = data.text ?? "";
    mediaSource = data.media ?? "";
    anim.running = true;
    pauseTime = data.pause ?? 2000;
    fadeTime = data.fade ?? 500;
  }
}
