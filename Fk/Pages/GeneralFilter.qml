// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
  id: root
  height: parent.height - 32
  width: parent.width - 32
  x: 8
  y: 8
  //anchors.fill: parent
  //anchors.margins: 8
  clip: true
  contentWidth: layout.width
  contentHeight: layout.height
  ScrollBar.vertical: ScrollBar {}
  // ScrollBar.horizontal: ScrollBar {}

  signal finished(var data)

  ColumnLayout {
    id: layout
    anchors.top: parent.top

    Item { Layout.fillHeight: true }

    // extension, package, kingdom, subkingdom, hp,
    // maxHp, mainMaxHpAdjustedValue, deputyMaxHpAdjustedValue,
    // gender, shield, hidden, skill, companions

    //GridLayout {
    //columns: 2

    GridLayout {
      columns: 2

      // name
      RowLayout {
        anchors.rightMargin: 8
        spacing: 16
        Text {
          text: luatr("Name")
          font.bold: true
          font.pixelSize: 14
        }
        TextField {
          id: name
          maximumLength: 64
          font.pixelSize: 18
          Layout.rightMargin: 16
          Layout.fillWidth: true
          text: config.preferredFilter.name
        }
      }

      // title
      RowLayout {
        anchors.rightMargin: 8
        spacing: 16
        Text {
          text: luatr("Title")
          font.bold: true
          font.pixelSize: 14
        }
        TextField {
          id: title
          maximumLength: 64
          font.pixelSize: 18
          Layout.rightMargin: 16
          Layout.fillWidth: true
          text: config.preferredFilter.id
        }
      }
    }

    // kingdom
    Column {
      id: kingdomColumn
      property bool kingdomShown: false
      ButtonGroup {
        id: childKingdom
        exclusive: false
        checkState: parentKingdomBox.checkState
      }

      RowLayout {
        spacing: 8
        height: kingdomColumn.kingdomShown ? 32 : 36
        CheckBox {
          id: parentKingdomBox
          text: luatr("Kingdom")
          font.bold: true
          checkState: childKingdom.checkState
          Layout.minimumWidth: 100
        }
        ToolButton {
          text: (kingdomColumn.kingdomShown ? "➖" : "➕")
          onClicked: {
            kingdomColumn.kingdomShown = !kingdomColumn.kingdomShown
          }
          background: Rectangle {
            implicitWidth: 20
            implicitHeight: 20

            visible: parent.down || parent.checked || parent.highlighted || parent.visualFocus
              || (parent.enabled && parent.hovered)
          }
        }
      }

      GridLayout {
        columns: 10
        height: parent.kingdomShown ? kingdomStates.contentHeight : 0
        visible: parent.kingdomShown

        Repeater {
          id: kingdomStates

          CheckBox {
            text: luatr(modelData)
            leftPadding: indicator.width
            ButtonGroup.group: childKingdom
          }
        }
      }
    }

    // maxHp
    Column {
      id: maxHpColumn
      property bool maxHpShown: false
      ButtonGroup {
        id: childMaxHp
        exclusive: false
        checkState: parentMaxHpBox.checkState
      }

      RowLayout {
        spacing: 8
        height: maxHpColumn.maxHpShown ? 32 : 36
        CheckBox {
          id: parentMaxHpBox
          text: luatr("MaxHp")
          font.bold: true
          checkState: childMaxHp.checkState
          Layout.minimumWidth: 100
        }
        ToolButton {
          text: (maxHpColumn.maxHpShown ? "➖" : "➕")
          onClicked: {
            maxHpColumn.maxHpShown = !maxHpColumn.maxHpShown
          }
          background: Rectangle {
            implicitWidth: 20
            implicitHeight: 20

            visible: parent.down || parent.checked || parent.highlighted || parent.visualFocus
              || (parent.enabled && parent.hovered)
          }
        }
      }

      GridLayout {
        columns: 10
        height: parent.maxHpShown ? maxHpStates.contentHeigh : 0
        visible: parent.maxHpShown

        Repeater {
          id: maxHpStates

          CheckBox {
            text: modelData
            leftPadding: indicator.width
            ButtonGroup.group: childMaxHp
          }
        }
      }
    }

    // hp
    Column {
      id: hpColumn
      property bool hpShown: false
      ButtonGroup {
        id: childHp
        exclusive: false
        checkState: parentHpBox.checkState
      }

      RowLayout {
        spacing: 8
        height: hpColumn.hpShown ? 32 : 36
        CheckBox {
          id: parentHpBox
          text: luatr("Hp")
          font.bold: true
          checkState: childHp.checkState
          Layout.minimumWidth: 100
        }
        ToolButton {
          text: (hpColumn.hpShown ? "➖" : "➕")
          onClicked: {
            hpColumn.hpShown = !hpColumn.hpShown
          }
          background: Rectangle {
            implicitWidth: 20
            implicitHeight: 20

            visible: parent.down || parent.checked || parent.highlighted || parent.visualFocus
              || (parent.enabled && parent.hovered)
          }
        }
      }

      GridLayout {
        columns: 10
        height: parent.hpShown ? hpStates.contentHeigh : 0
        visible: parent.hpShown

        Repeater {
          id: hpStates

          CheckBox {
            text: modelData
            leftPadding: indicator.width
            ButtonGroup.group: childHp
          }
        }
      }
    }

    // gender
    Column {
      id: genderColumn
      property bool genderShown: false
      ButtonGroup {
        id: childGender
        exclusive: false
        checkState: parentGenderBox.checkState
      }

      RowLayout {
        spacing: 8
        height: genderColumn.genderShown ? 32 : 36
        CheckBox {
          id: parentGenderBox
          text: luatr("Gender")
          font.bold: true
          checkState: childGender.checkState
          Layout.minimumWidth: 100
        }
        ToolButton {
          text: (genderColumn.genderShown ? "➖" : "➕")
          onClicked: {
            genderColumn.genderShown = !genderColumn.genderShown
          }
          background: Rectangle {
            implicitWidth: 20
            implicitHeight: 20

            visible: parent.down || parent.checked || parent.highlighted || parent.visualFocus
              || (parent.enabled && parent.hovered)
          }
        }
      }

      GridLayout {
        columns: 6
        height: parent.genderShown ? gendersStates.contentHeigh : 0
        visible: parent.genderShown

        Repeater {
          id: gendersStates
          model: ["male", "female", "bigender", "agender"]

          CheckBox {
            text: luatr(modelData)
            leftPadding: indicator.width
            ButtonGroup.group: childGender
          }
        }
      }
    }

    GridLayout {
      anchors.topMargin: 8
      columns: 2

      // skillName
      RowLayout {
        anchors.rightMargin: 8
        spacing: 16
        Text {
          text: luatr("Skill Name")
          font.bold: true
          font.pixelSize: 14
        }
        TextField {
          id: skillName
          maximumLength: 64
          font.pixelSize: 18
          Layout.rightMargin: 16
          Layout.fillWidth: true
          text: config.preferredFilter.name
        }
      }

      // skillDesc
      RowLayout {
        anchors.rightMargin: 8
        spacing: 16
        Text {
          text: luatr("Skill Description")
          font.bold: true
          font.pixelSize: 14
        }
        TextField {
          id: skillDesc
          maximumLength: 64
          font.pixelSize: 18
          Layout.rightMargin: 16
          Layout.fillWidth: true
          text: config.preferredFilter.id
        }
      }
    }
    // information
    GridLayout {
      columns: 4

      // designer
      RowLayout {
        anchors.rightMargin: 8
        spacing: 8
        Text {
          text: luatr("Designer")
          font.bold: true
          font.pixelSize: 14
        }
        TextField {
          id: designer
          maximumLength: 64
          font.pixelSize: 18
          Layout.rightMargin: 16
          Layout.fillWidth: true
          text: config.preferredFilter.name
        }
      }

      // voice actor
      RowLayout {
        anchors.rightMargin: 8
        spacing: 8
        Text {
          text: luatr("Voice Actor")
          font.bold: true
          font.pixelSize: 14
        }
        TextField {
          id: voiceActor
          maximumLength: 64
          font.pixelSize: 18
          Layout.rightMargin: 16
          Layout.fillWidth: true
          text: config.preferredFilter.name
        }
      }

      // illustrator
      RowLayout {
        anchors.rightMargin: 8
        spacing: 8
        Text {
          text: luatr("Illustrator")
          font.bold: true
          font.pixelSize: 14
        }
        TextField {
          id: illustrator
          maximumLength: 64
          font.pixelSize: 18
          Layout.rightMargin: 16
          Layout.fillWidth: true
          text: config.preferredFilter.name
        }
      }

      // audioText
      RowLayout {
        anchors.rightMargin: 8
        spacing: 8
        Text {
          text: luatr("Audio Text")
          font.bold: true
          font.pixelSize: 14
        }
        TextField {
          id: audioText
          maximumLength: 64
          font.pixelSize: 18
          Layout.rightMargin: 16
          Layout.fillWidth: true
          text: config.preferredFilter.id
        }
      }
    }

    RowLayout {
      Layout.alignment: Qt.AlignRight
      anchors.rightMargin: 8
      // spacing: 64
      // Layout.fillWidth: true

      Button {
        text: luatr("Clear")
        onClicked: {
          root.finished(false);
        }
      }

      Button {
        text: luatr("OK")
        onClicked: {
          root.finished(output());
        }
      }
    }

    Component.onCompleted: {
      const properties = lcall("GetAllProperties");
      kingdomStates.model = properties.kingdoms;
      maxHpStates.model = properties.maxHps;
      hpStates.model = properties.hps;
      //shieldStates.model = properties.shields;
    }
  }

  function getCheck(box, states) {
    let ret = [];
    if (box.checkState === Qt.PartiallyChecked) {
      for (let index = 0; index < states.count; index++) {
        var tCheckBox = states.itemAt(index)
        if (tCheckBox.checked) {ret.push(tCheckBox.text)}
      }
    }
    return ret;
  }

  function output() {
    let f = {};
    // name
    f.name = name.text;
    // title
    f.title = title.text;
    // kingdom
    f.kingdoms = getCheck(parentKingdomBox, kingdomStates);
    // maxHp
    f.maxHps = getCheck(parentMaxHpBox, maxHpStates);
    // hp
    f.hps = getCheck(parentHpBox, hpStates);
    // shield
    // f.shield = getCheck(parentShieldBox, shieldStates);
    // gender
    f.genders = getCheck(parentGenderBox, gendersStates);
    // skillName
    f.skillName = skillName.text;
    // skillDesc
    f.skillDesc = skillDesc.text;
    // designer
    f.designer = designer.text;
    // voiceActor
    f.voiceActor = voiceActor.text;
    // illustrator
    f.illustrator = illustrator.text;
    // audioText
    f.audioText = audioText.text;
    return f;
  }
}
