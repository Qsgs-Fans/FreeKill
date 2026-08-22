// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Qt5Compat.GraphicalEffects

import Fk
import Fk.Components.Common
import Fk.Widgets as W

import LunarLtk
import LunarLtk.Components
import LunarLtk.Components.Photo as PhotoElement

RoomBase {
  id: roomScene

  property alias okCancel: okCancel
  property alias okButton: okButton
  property alias cancelButton: cancelButton

  property alias menuButton: menuButton
  signal menuButtonClicked()

  // required property 填写区
  roomArea: roomArea
  progress: progress
  progressAnim: progressAnim
  skillInteraction: skillInteraction
  dashboard: dashboard
  drawPile: drawPile
  tablePile: tablePile

  /* Layout:
   * +---------------------+
   * |   Photos, get more  |
   * | in arrangePhotos()  |
   * |      tablePile      |
   * | progress,prompt,btn |
   * +---------------------+
   * |      dashboard      |
   * +---------------------+
   */

  Item {
    id: roomArea
    width: roomScene.width
    height: roomScene.height - dashboard.height + 20

    Repeater {
      id: photos
      model: photoModel
      Photo {
        required property PhotoModel modelData
        dataModel: modelData

        onRightClicked: {
          if (playerid === 0 || playerid === -1) return;
          roomScene.showInfoPopup(
            Qt.createComponent("LunarLtk.Pages.InfoPopups", "PlayerDetail"),
            { dataModel });
        }

        Component.onCompleted: {
          // if (dataModel.playerid === roomScene.dataModel.dashboardId) {
          //   enableChangeSkin = true;
          // }
          enableChangeSkin = false; // 经典ui关闭
        }
      }
    }

    onWidthChanged: arrangePhotos();
    onHeightChanged: arrangePhotos();

    InvisibleCardArea {
      id: drawPile
      x: parent.width / 2
      y: roomScene.height / 2
    }

    TablePile {
      id: tablePile
      roomModel: roomScene.dataModel

      width: parent.width * 0.7
      height: 150
      x: parent.width * 0.15
      y: parent.height * 0.6 + 10
    }
  }

  Item {
    id: dashboardBtn
    width: childrenRect.width
    height: childrenRect.height
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 8
    anchors.left: parent.left
    anchors.leftMargin: 8
    ColumnLayout {
      MetroButton {
        text: Lua.tr("Choose one handcard")
        textFont.pixelSize: 28
        visible: {
          if (!progressAnim.running) return false;
          if (dashboard.handcardArea.folded) return true;
          if (dashboard.handcardArea.length <= 15) {
            return false;
          }
          const cards = dashboard.handcardArea.cards;
          for (const card of cards) {
            if (card.selectable) return true;
          }
          return false;
        }
        onClicked: {
          if (dashboard.handcardArea.folded) {
            const params = { name: "hand_card" };
            let data = dashboard.dataModel.handcards.map(e => { return e.uniqueId } );
            data = data.filter((e) => Lua.selfPlayer.cardVisible(e));

            params.ids = data;
            params.additional_prop = { selectable: true, markVisible: true };

            // Just for using room's right drawer
            roomScene.showInfoPopup(Qt.createComponent("LunarLtk.Pages.InfoPopups", "ViewPile"), params);

          } else
            roomScene.showInfoPopup(Qt.createComponent("LunarLtk.Pages.InfoPopups", "ChooseHandcard"));
        }
      }
      MetroButton {
        id: trustBtn
        text: Lua.tr("Trust")
        enabled: !Config.observing && !Config.replaying
        visible: !Config.observing && !Config.replaying
        textFont.pixelSize: 28
        onClicked: {
          Cpp.notifyServer("Trust", "");
          trustBtn.enabled = false;
          roomScene.dataModel.deActivate();
        }
      }
      MetroButton {
        id: revertSelectionBtn
        enabled: !dashboard.handcardArea.folded
        text: Lua.tr("Revert Selection")
        textFont.pixelSize: 28
        onClicked: Ltk.revertSelection();
      }
      MetroButton {
        id: sortBtn
        text: Lua.tr("Sort Cards")
        textFont.pixelSize: 28
        enabled: dashboard.sortable
        onClicked: {
          if (dashboard.sortable) {
            let sortMethod = 0;
            for (let index = 0; index < sortMenuRepeater.count; index++) {
              var tCheckBox = sortMenuRepeater.itemAt(index)
              if (tCheckBox.checked) sortMethod = index;
            }
            roomScene.dataModel.dashboard.sortHandcards(sortMethod);
          }
        }

        onRightClicked: {
          if (sortMenu.visible) {
            sortMenu.close();
          } else {
            sortMenu.open();
          }
        }

        ToolTip {
          id: sortTip
          x: 20
          y: -20
          visible: parent.hovered && !sortMenu.visible
          delay: 1500
          timeout: 6000
          text: Lua.tr("Right click or long press to choose sort method")
          font.pixelSize: 20
        }

        Menu {
          id: sortMenu
          x: parent.width
          y: -25
          width: parent.width * 2
          background: Rectangle {
            color: "black"
            border.width: 3
            border.color: "white"
            opacity: 0.8
          }

          Repeater {
            id: sortMenuRepeater
            model: ["Sort by Type", "Sort by Number", "Sort by Suit"]

            RadioButton {
              id: control
              text: "<font color='white'>" + Lua.tr(modelData) + "</font>"
              checked: modelData === "Sort by Type"
              font.pixelSize: 20

              indicator: Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                x: control.leftPadding
                y: control.height / 2 - height / 2
                radius: 3
                border.color: "white"

                Rectangle {
                  width: 14
                  height: 14
                  x: 6
                  y: 6
                  radius: 2
                  color: control.down ? "#17a81a" : "#21be2b"
                  visible: control.checked
                }
              }
            }
          }
        }
      }
      MetroButton {
        text: Lua.tr("Chat")
        textFont.pixelSize: 28
        onClicked: Mediator.notify(this, Command.IWantToChat);
      }
    }
  }

  Dashboard {
    id: dashboard
    width: roomScene.width - dashboardBtn.width
    anchors.top: roomArea.bottom
    anchors.left: dashboardBtn.right

    dataModel: roomScene.dataModel.dashboard
  }

  Item {
    id: controls
    anchors.bottom: dashboard.top
    anchors.bottomMargin: -60
    width: roomScene.width

    Text {
      id: prompt
      visible: progress.visible
      anchors.bottom: progress.bottom
      z: 1
      text: roomScene.dataModel.promptText
      color: "#F0E5DA"
      font.pixelSize: 16
      font.family: Config.libianName
      style: Text.Outline
      styleColor: "#3D2D1C"
      textFormat: TextEdit.RichText
      anchors.horizontalCenter: progress.horizontalCenter
    }

    ProgressBar {
      id: progress
      width: parent.width * 0.6
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: okCancel.top
      anchors.bottomMargin: 4
      from: 0.0
      to: 100.0

      visible: false

      background: Rectangle {
        implicitWidth: 200
        implicitHeight: 12
        color: "black"
        radius: 6
      }

      contentItem: Item {
        implicitWidth: 196
        implicitHeight: 10

        Rectangle {
          width: progress.visualPosition * parent.width
          height: parent.height
          radius: 6
          gradient: Gradient {
            GradientStop { position: 0.0; color: "orange" }
            GradientStop { position: 0.3; color: "red" }
            GradientStop { position: 0.7; color: "red" }
            GradientStop { position: 1.0; color: "orange" }
          }
        }
      }

      NumberAnimation on value {
        id: progressAnim
        running: progress.visible
        from: 100.0
        to: 0.0
        duration: Config.roomTimeout * 1000

        onFinished: {
          roomScene.dataModel.deActivate();
        }
      }
    }

    Rectangle {
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 8
      anchors.right: okCancel.left
      anchors.rightMargin: 20
      color: "#88EEEEEE"
      radius: 8
      visible: {
        if (!progress.visible) {
          return false;
        }
        if (!specialCardSkills) {
          return false;
        }
        if (specialCardSkills.count > 1) {
          return true;
        }
        return (specialCardSkills.model ?? false)
            && specialCardSkills.model[0] !== "_normal_use"
      }
      width: childrenRect.width
      height: childrenRect.height - 20

      RowLayout {
        y: -10
        Repeater {
          id: specialCardSkills
          RadioButton {
            property string orig_text: modelData
            text: Lua.tr(modelData)
            checked: index === 0
            onCheckedChanged: {
              Lua.updateRequestUI("SpecialSkills", "1", "click", modelData);
            }
          }
        }
      }
    }

    Loader {
      id: skillInteraction
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 8
      anchors.right: okCancel.left
      anchors.rightMargin: 20
    }

    component OKCancelButton: MetroButton {
      width: 136
      height: 56
      padding: 8
      textFont.bold: true
      textFont.family: Config.libianName
      textFont.pixelSize: 20
      title.style: Text.Outline
    }

    Row {
      id: okCancel
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: progress.horizontalCenter
      spacing: 20
      visible: dataModel.okCancelVisible && !roomScene.dataModel.optionVisible

      OKCancelButton {
        id: skipNullificationButton
        text: Lua.tr("SkipNullification")
        visible: dataModel.canSkipNullification
        onClicked: {
          dataModel.skipNullification();
        }
      }

      OKCancelButton {
        id: okButton
        textColor: "#f7dbcb"
        title.styleColor: "#975a36"
        backgroundColor: "#C26028"
        enabled: dataModel.okEnabled
        text: Lua.tr("OK")
        onClicked: Lua.updateRequestUI("Button", "OK");
      }

      OKCancelButton {
        id: cancelButton
        textColor: "#f4dbc1"
        title.styleColor: "#746c60"
        backgroundColor: "#ae7842"
        enabled: dataModel.cancelEnabled
        text: Lua.tr("Cancel")
        onClicked: Lua.updateRequestUI("Button", "Cancel");
      }
    }

    OptionArea {
      id: optionArea
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 7
      anchors.horizontalCenter: progress.horizontalCenter
      spacing: 20
      visible: roomScene.dataModel.optionVisible
      
      dataModel: roomScene.dataModel.options
    }

    OKCancelButton {
      id: endPhaseButton
      text: Lua.tr("End")
      textColor: "#d0eff0"
      title.styleColor: "#426b6d"
      backgroundColor: "#42b1b5"
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 40
      anchors.right: parent.right
      anchors.rightMargin: 30
      visible: dataModel.endButtonVisible
      onClicked: Lua.updateRequestUI("Button", "End");
    }
  }

  ToastManager {
    id: popupLogArea
    height: roomArea.height * 0.61
    width: roomArea.width
    spacing: 2
    z: 10

    delegate: Toast {
      required property string text
      required property real duration
      required property int index
      required property var listmodel

      color: "#eff2ecc8"
      height: message.height + 8
      width: message.width + 18
      radius: 4
      message.font.pixelSize: 14

      onFinished: {
        listmodel.remove(index);
      }

      Component.onCompleted: {
        show(text, duration);
      }
    }
  }

  GlowText {
    anchors.centerIn: dashboard
    visible: getPhoto(Cpp.self.id).rest > 0 && !Config.observing
    text: Lua.tr("Resting, don't leave!")
    color: "#DBCC69"
    font.family: Config.libianName
    font.pixelSize: 28
    glow.color: "#2E200F"
    glow.spread: 0.6
  }

  Rectangle {
    anchors.fill: dashboard
    visible: Config.observing && !Config.replaying
    color: "transparent"
    z: 10
    GlowText {
      anchors.centerIn: parent
      text: Lua.tr("Observing ...")
      color: "#4B83CD"
      font.family: Config.li2Name
      font.pixelSize: 48
    }
  }

  MiscStatus {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 68
    anchors.topMargin: 8

    dataModel: roomScene.dataModel
  }

  OKCancelButton {
    id: menuButton
    width: 64
    height: 64
    anchors.top: parent.top
    anchors.topMargin: 4
    anchors.right: parent.right
    anchors.rightMargin: 4 
    icon.sourceSize: Qt.size(32, 32)
    icon.source: Cpp.path + "/image/symbolic/actions/open-menu-symbolic.svg"
    icon.layer.enabled: true
    icon.layer.effect: ColorOverlay {
      color: menuButton.textColor
    }
    // text: Lua.tr("Menu")
    onClicked: roomScene.menuButtonClicked();
  }

  PhotoElement.MarkArea {
    x: 12; y: 12
    width: ((roomScene.width - 175 * 0.75 * 7) / 4 + 175 - 16) * 0.75
    transformOrigin: Item.TopLeft
    bgColor: "#BB838AEA"

    markModel: roomScene.dataModel.banners
  }
}
