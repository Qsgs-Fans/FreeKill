import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Fk

Item {
  id: root
  anchors.fill: parent
  property string generalName: "liubei"
  property string skillName

  Rectangle {
    id: mask
    anchors.fill: parent
    color: "black"
    opacity: 0.5
  }

  GridLayout {
    id: bg1
    columns: 20
    columnSpacing: 30
    rowSpacing: 70
    y: (root.height - height) / 2 + 25
    x: -300
    opacity: 0
    Repeater {
      model: 40
      Text {
        text: {
          let o = "$" + skillName + "_" + generalName + (index % 2 + 1);
          let p = Lua.tr(o);
          if (o !== p) {
            return p;
          }
          o = "$" + skillName + (index % 2 + 1);
          p = Lua.tr(o);
          if (o === p) {
            return "Ultimate Skill Invoked!";
          }
          return p;
        }
        color: "white"
        font.pixelSize: 30
        font.family: Config.libianName
      }
    }
  }

  GridLayout {
    id: bg2
    columns: 20
    columnSpacing: 30
    rowSpacing: 70
    y: (root.height - height) / 2 - 25
    x: -250
    opacity: 0
    Repeater {
      model: 40
      Text {
        text: {
          let o = "$" + skillName + "_" + generalName + ((index + 1) % 2 + 1);
          let p = Lua.tr(o);
          if (o !== p) {
            return p;
          }
          o = "$" + skillName + ((index + 1) % 2 + 1);
          p = Lua.tr(o);
          if (o === p) {
            return "Ultimate Skill Invoked!";
          }
          return p;
        }
        color: "white"
        font.pixelSize: 30
        font.family: Config.libianName
      }
    }
  }

  GeneralCardItem {
    id: herocard
    name: generalName
    scale: 2.7
    x: root.width + 140
    anchors.verticalCenter: parent.verticalCenter
    opacity: 0
    detailed: false
  }

  Text {
    topPadding: 5
    id: skill
    text: Lua.tr(skillName)
    font.family: Config.li2Name
    font.pixelSize: 40
    x: root.width / 2 + 100
    y: root.height + 300
    color: "snow"
    opacity: 0
    scale: 3
    style: Text.Outline
  }

  ParallelAnimation {
    running: true
    PropertyAnimation {
      target: bg1
      property: "x"
      to: -200
      duration: 2000
    }

    PropertyAnimation {
      target: bg2
      property: "x"
      to: -350
      duration: 2000
    }
  }

  SequentialAnimation {
    id: anim
    running: false

    ParallelAnimation {
      PropertyAnimation {
        targets: [ herocard, skill, bg1, bg2 ]
        property: "opacity"
        to: 1
        duration: 500
      }

      PropertyAnimation {
        target: herocard
        property: "scale"
        to: 3.3
        duration: 500
      }

      PropertyAnimation {
        target: herocard
        property: "x"
        to: (root.width - herocard.width) / 2 - 40
        duration: 500
        easing.type: Easing.InQuad
      }

      PropertyAnimation {
        target: skill
        property: "y"
        to: root.height / 2 + 120
        duration: 500
      }
    }

    ParallelAnimation {
      PropertyAnimation {
        target: herocard
        property: "x"
        to: (root.width - herocard.width) / 2 - 120
        duration: 1000
      }

      PropertyAnimation {
        target: skill
        property: "y"
        to: root.height / 2 + 80
        duration: 1000
      }
    }

    ParallelAnimation {
      PropertyAnimation {
        targets: [ herocard, skill, mask, bg1, bg2 ]
        property: "opacity"
        to: 0
        duration: 500
      }

      PropertyAnimation {
        target: herocard
        property: "scale"
        to: 2.7
        duration: 500
      }

      PropertyAnimation {
        target: herocard
        property: "x"
        to: -100 - herocard.width
        duration: 500
        easing.type: Easing.OutQuad
      }

      PropertyAnimation {
        target: skill
        property: "y"
        to: -300
        duration: 500
        easing.type: Easing.OutQuad
      }
    }

    onFinished: {
      roomScene.bigAnim.source = "";
    }
  }

  function loadData(data) {
    generalName = data.general;
    skillName = data.skill_name;
    anim.running = true;
  }
}
