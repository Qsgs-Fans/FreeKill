// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Fk.RoomElement

Item {
  id: root

  property bool loaded: false

  Rectangle {
    anchors.fill: listView
    color: "#88EEEEEE"
    radius: 6
  }

  ListView {
    id: listView
    width: 130
    height: parent.height - 20
    y: 10
    ScrollBar.vertical: ScrollBar {}
    model: ListModel {
      id: packages
    }

    highlight: Rectangle { color: "#E91E63"; radius: 5 }
    highlightMoveDuration: 500

    delegate: Item {
      width: listView.width
      height: 40

      Text {
        text: Backend.translate(name)
        anchors.centerIn: parent
      }

      TapHandler {
        onTapped: {
          listView.currentIndex = index;
        }
      }
    }

    onCurrentIndexChanged: { vanishAnim.start(); }
  }

  GridView {
    id: gridView
    width: root.width - listView.width - generalDetail.width - 16
    height: parent.height - 20
    y: 10
    anchors.left: listView.right
    anchors.leftMargin: 8 + (width % 100) / 2
    cellHeight: 140
    cellWidth: 100

    delegate: GeneralCardItem {
      autoBack: false
      name: modelData
      onClicked: {
        generalText.clear();
        generalDetail.general = modelData;
        generalDetail.updateGeneral();
      // generalDetail.open();
      }

      Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: config.disabledGenerals.includes(modelData) ? 0.7 : 0
        Behavior on opacity {
          NumberAnimation {}
        }
      }

      GlowText {
        visible: config.disabledGenerals.includes(modelData)
        text: '禁'
        anchors.centerIn: parent
        font.family: fontLi2.name
        color: "#E4D5A0"
        font.pixelSize: 36
        font.weight: Font.Medium
        glow.color: "black"
        glow.spread: 0.3
        glow.radius: 5
      }
    }
  }

  ParallelAnimation {
    id: vanishAnim
    PropertyAnimation {
      target: gridView
      property: "opacity"
      to: 0
      duration: 150
      easing.type: Easing.InOutQuad
    }
    PropertyAnimation {
      target: gridView
      property: "y"
      to: 30
      duration: 150
      easing.type: Easing.InOutQuad
    }
    onFinished: {
      gridView.model = JSON.parse(Backend.callLuaFunction("GetGenerals",
        [listView.model.get(listView.currentIndex).name]));
      appearAnim.start();
    }
  }

  SequentialAnimation {
    id: appearAnim
    PauseAnimation { duration: 200 }
    ParallelAnimation {
      PropertyAnimation {
        target: gridView
        property: "opacity"
        to: 1
        duration: 150
        easing.type: Easing.InOutQuad
      }
      PropertyAnimation {
        target: gridView
        property: "y"
        from: 20
        to: 10
        duration: 150
        easing.type: Easing.InOutQuad
      }
    }
  }

  Rectangle {
    id: generalDetail
    width: 310
    height: parent.height - 20
    y: 10
    anchors.right: parent.right
    anchors.rightMargin: 10
    color: "#88EEEEEE"
    radius: 8

    property string general: "caocao"

    function addSkillAudio(skill) {
      const skilldata = JSON.parse(Backend.callLuaFunction("GetSkillData", [skill]));
      const extension = skilldata.extension;
      for (let i = 0; i < 999; i++) {
        let fname = AppPath + "/packages/" + extension + "/audio/skill/" +
          skill + (i !== 0 ? i.toString() : "") + ".mp3";

        if (Backend.exists(fname)) {
          audioModel.append({ name: skill, idx: i });
        } else {
          if (i > 0) break;
        }
      }
    }

    function updateGeneral() {
      detailGeneralCard.name = general;
      const data = JSON.parse(Backend.callLuaFunction("GetGeneralDetail", [general]));
      generalText.clear();
      audioModel.clear();
      data.skill.forEach(t => {
        generalText.append("<b>" + Backend.translate(t.name) +
          "</b>: " + t.description);

        addSkillAudio(t.name);
      });
      data.related_skill.forEach(t => {
        generalText.append("<font color=\"purple\"><b>" + Backend.translate(t.name) +
          "</b>: " + t.description + "</font>");

        addSkillAudio(t.name);
      });
    }

    Flickable {
      flickableDirection: Flickable.VerticalFlick
      contentHeight: detailLayout.height
      width: parent.width - 40
      height: parent.height - 40
      clip: true
      anchors.centerIn: parent
      ScrollBar.vertical: ScrollBar {}

      ColumnLayout {
        id: detailLayout
        width: parent.width

        GeneralCardItem {
          id: detailGeneralCard
          Layout.alignment: Qt.AlignHCenter
          name: "caocao"
        }

        TextEdit {
          id: generalText

          Layout.fillWidth: true
          readOnly: true
          selectByKeyboard: true
          selectByMouse: false
          wrapMode: TextEdit.WordWrap
          textFormat: TextEdit.RichText
          font.pixelSize: 16
        }

        Repeater {
          model: ListModel {
            id: audioModel
          }
          Button {
            Layout.fillWidth: true
            contentItem: ColumnLayout {
              Text {
                Layout.fillWidth: true
                text: Backend.translate(name) + (idx ? " (" + idx.toString() + ")" : "")
                font.bold: true
                font.pixelSize: 14
              }
              Text {
                Layout.fillWidth: true
                text: Backend.translate("$" + name + (idx ? idx.toString() : ""))
                wrapMode: Text.WordWrap
              }
            }

            onClicked: {
              const skilldata = JSON.parse(Backend.callLuaFunction("GetSkillData", [name]));
              const extension = skilldata.extension;
              Backend.playSound("./packages/" + extension +
                "/audio/skill/" + name, idx);
            }
          }
        }

        Button {
          Layout.fillWidth: true
          contentItem: ColumnLayout {
            Text {
              Layout.fillWidth: true
              text: Backend.translate("Death audio")
              font.bold: true
              font.pixelSize: 14
            }
            Text {
              Layout.fillWidth: true
              text: Backend.translate("~" + generalDetail.general)
              wrapMode: Text.WordWrap
            }
          }

          onClicked: {
            const general = generalDetail.general
            const extension = JSON.parse(Backend.callLuaFunction("GetGeneralData", [general])).extension;
            Backend.playSound("./packages/" + extension + "/audio/death/" + general);
          }
        }
      }
    }
  }

  ColumnLayout {
    anchors.right: parent.right
    Button {
      text: Backend.translate("Quit")
      onClicked: {
        mainStack.pop();
        config.saveConf();
      }
    }

    Button {
      id: banButton
      text: Backend.translate(config.disabledGenerals.includes(detailGeneralCard.name) ? 'ResumeGeneral' : 'BanGeneral')
      visible: detailGeneralCard.name
      onClicked: {
        const { disabledGenerals } = config;
        const { name } = detailGeneralCard;

        if (banButton.text === Backend.translate('ResumeGeneral')) {
          const deleteIndex = disabledGenerals.findIndex((general) => general === name);
          if (deleteIndex === -1) {
            return;
          }

          disabledGenerals.splice(deleteIndex, 1);
        } else {
          if (disabledGenerals.includes(name)) {
            return;
          }

          disabledGenerals.push(name);
        }
        config.disabledGeneralsChanged();
      }
    }
  }

  function loadPackages() {
    if (loaded) return;
    const packs = JSON.parse(Backend.callLuaFunction("GetAllGeneralPack", []));
    packs.forEach((name) => packages.append({ name: name }));
    generalDetail.updateGeneral();
    loaded = true;
  }
}
