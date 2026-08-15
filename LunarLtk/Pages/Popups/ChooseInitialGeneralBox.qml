// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Fk
import Fk.Components.Common
import Fk.Components.GameCommon as Game
import LunarLtk
import LunarLtk.Components
import LunarLtk.Models.Popups

pragma ComponentBehavior: Bound

GraphicsBox {
  id: root

  required property ChooseInitialGeneralModel dataModel

  property alias generalCardList: generalCardList

  property var draggingCard: null

  property var roomScene: parent

  onShown: {
    y = (roomScene.height - height)/2;
    arrangeCards()
  }

  Connections {
    target: root.dataModel
    function onGeneralChanged(idx, newName) {
      const item = generalCardList.itemAt(idx);
      item.dataModel = root.dataModel.generalDict[idx];
      root.arrangeCards();
    }
  }

  title.text: dataModel.promptText
  width: control.width + rightArea.width + 15
  height: 500

  Flickable {
    id: control
    anchors.left: parent.left
    anchors.leftMargin: 10
    anchors.top: parent.top
    anchors.topMargin: 30
    anchors.bottom: progress.top
    anchors.bottomMargin: 10
    width: 98 * coloumNum + 20

    property int coloumNum: Math.min(Math.ceil(root.dataModel.generals.length / 3), 6)

    clip:true

    contentHeight: generalFlow.height + 10

    Flow {
      id: generalFlow
      spacing: 5
      x: 3; y: 6
      width: parent.width
      height:childrenRect.height

      Repeater {
        id: generalCardList
        model: root.dataModel.generals

        GeneralCardItem {
          required property string modelData
          required property int index
          property bool hovered: false
          dataModel: root.dataModel.generalDict[index]
          selectable: {
            if (root.dataModel.choiceNum == 1) return true
            const result = root.dataModel.resultInt.map(e => Number(e));
            if (result) {
              return result.includes(index) || root.dataModel.generalFilter(index);
            }
            return false;
          }

          HoverHandler {
            cursorShape: parent.selectable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onHoveredChanged: {
              if (hovered && parent.selectable) {
                parent.hovered = true;
              } else {
                parent.hovered = false;
              }
            }
          }

          Rectangle {
            anchors.fill:parent
            anchors.margins: -2
            color: "white"
            z: -1
            radius: 1
            visible: parent.hovered
          }

          Rectangle {
            anchors.fill:parent
            color:"transparent"
            border.width:4
            border.color:'#d3fdde2d'
            visible: parent.selected
            Rectangle {
              anchors.fill:parent
              color:"transparent"
              border.width:2
              border.color:'#eec7aa07'
            }
            GlowText {
              width: parent.width
              anchors.centerIn: parent
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              lineHeight:40
              lineHeightMode: Text.FixedHeight
              font.pixelSize: 45
              font.family: Config.li2Name
              color: '#fdf142'
              glow.radius: 3
              glow.spread: 0.9
              glow.color: '#312313'
              text: {
                if (root.dataModel.choiceNum === 2) {
                  const arr = root.dataModel.resultInt
                  const idx = parent.parent.index
                  if (arr.indexOf(idx) === 0) {
                    return "主将".split("").join("\n")
                  } else if (arr.indexOf(idx) === 1) {
                    return "副将".split("").join("\n")
                  }
                }
                return "已选".split("").join("\n")
              }
            }
          }

          onClicked: {
            if (!selectable) return;
            root.dataModel.selectGeneralCard(index);
            root.arrangeCards();
          }

          onRightClicked: {
            if (Lua.client.getSettings("enableFreeAssign")) {
              roomScene.showInfoPopup(Qt.createComponent("LunarLtk.Pages.InfoPopups", "FreeAssign"),
              { dataModel: root.dataModel, index: index });
            }
          }
        }
      }
    }

    ScrollBar.vertical: ScrollBar {
      id: verticalBar
      parent: control
      height: control.height
      width: 15

      contentItem: Rectangle {
        implicitWidth: verticalBar.interactive ? 6 : 2
        implicitHeight: verticalBar.interactive ? 6 : 2

        radius: width / 2
        color: "#CCFFFFFF"
      }

      background: Rectangle {
        opacity: control.contentItem.opacity
        color: "#33000000"
      }
    }
  }

  Column {
    id: rightArea
    width: 350
    spacing: 0
    anchors.right: parent.right
    anchors.rightMargin: 10
    anchors.top: parent.top
    anchors.topMargin: 30
    anchors.bottom: progress.top
    anchors.bottomMargin: 10

    Item {
      id: lordSelectionArea
      width: parent.width
      height: 50

      Text {
        id: lordGeneralText
        anchors.left: parent.left
        anchors.leftMargin: 50
        height: parent.height
        width: 130
        text: {
          if (root.dataModel.hegemony) {
            return "启用势力："
          }
          return (root.dataModel.lordRole ? Lua.tr(root.dataModel.lordRole) : Lua.tr("lord")) + "已选择："
        }
        font.pixelSize: 22
        font.family: Config.li2Name
        color: "white"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        visible: root.dataModel.lordGeneral || root.dataModel.hegemony
      }

      CompactGeneralCardItem {
        id: lordGeneralAvatar
        width: 50; height: 50
        anchors.left: lordGeneralText.right
        dataModel: root.dataModel.lordGeneral ? Ltk.createGeneralCardModel(root.dataModel.lordGeneral) : Ltk.createGeneralCardModel("caocao")
        visible: root.dataModel.lordGeneral
      }

      CompactGeneralCardItem {
        id: lordDeputyAvatar
        width: 50; height: 50
        anchors.left: lordGeneralAvatar.right
        anchors.leftMargin: 5
        dataModel: root.dataModel.lordDeputy ? Ltk.createGeneralCardModel(root.dataModel.lordDeputy) : Ltk.createGeneralCardModel("caocao")
        visible: root.dataModel.lordDeputy
      }

      Rectangle {
        anchors.left: lordGeneralText.right
        anchors.right: parent.right
        anchors.rightMargin: 10
        height: Math.max(parent.height, hegEnabledKingdomFlow.height)
        color: '#93555555'
        radius: 5
        visible: hegEnabledKingdomFlow.visible
        Flow {
          id: hegEnabledKingdomFlow
          height: Math.ceil(root.dataModel.enabledKingdoms.length / 6) * 25
          width: root.dataModel.enabledKingdoms.length * 25
          anchors.verticalCenter: parent.verticalCenter
          visible: root.dataModel.hegemony

          Repeater {
            model: root.dataModel.enabledKingdoms
            Image {
              required property string modelData
              width: 25; height: 25
              source: {
                const ret = SkinBank.getGeneralCardDir(modelData) + modelData;
                if (Backend.exists(ret + ".png")) return ret;
                return ""
              }
            }
          }
        }
      }
    }

    Text {
      width: parent.width
      height: 45
      wrapMode: Text.WrapAnywhere
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignBottom
      text: root.dataModel.hegemony ? "你的势力是" : "你的身份是"
      font.pixelSize: 22
      font.family: "LiSu"
      color: "white"
      visible: root.dataModel.selfRole && !root.dataModel.hideRole
    }

    GlowText {
      id: selfRole
      width: parent.width
      height: 45
      horizontalAlignment: Text.AlignHCenter
      text: Lua.tr(root.dataModel.selfRole)
      font.pixelSize: 25
      font.family: "LiSu"
      color: (root.dataModel.selfRole in roleColor) ? roleColor[root.dataModel.selfRole] :"white"
      glow.color: "black"
      glow.spread: 1
      glow.radius: 2.5

      visible: root.dataModel.selfRole && !root.dataModel.hideRole && !root.dataModel.hegemony
      readonly property var roleColor: {
        "lord": '#c00707',
        "loyalist": '#e7b100',
        "rebel": '#0a6d0a',
        "renegade": '#0d32ac',
        "rebel_chief": '#0a6d0a'
      }
    }

    Image {
      id: selfKingdom
      height: 45
      width: 45
      anchors.horizontalCenter: parent.horizontalCenter
      visible: root.dataModel.hegemony
      source: {
        const mainGeneral = Ltk.getGeneralData(root.dataModel.generalResult[0] ?? "caocao")
        if (mainGeneral?.kingdom === "wild") {
          return SkinBank.getGeneralCardDir("wild") + "wild"
        }
        if (root.dataModel.selectedKingdom) return SkinBank.getGeneralCardDir(root.dataModel.selectedKingdom) + root.dataModel.selectedKingdom;
        const kingdom = Ltk.getKingdomInHegemony(root.dataModel.generalResult[0], root.dataModel.generalResult[1] ?? "", root.dataModel.enabledKingdoms)
        if (kingdom.length == 1) {
          return SkinBank.getGeneralCardDir(kingdom[0]) + `${kingdom[0]}`
        }
        return ""
      }
    }

    Row {
      width: implicitWidth
      height: implicitHeight + 10
      spacing: 10
      anchors.horizontalCenter: parent.horizontalCenter

      Repeater {
        model: root.dataModel?.choiceNum ?? 0
        Rectangle {
          required property int index
          color: "#1D1E19"
          radius: 3
          width: 95 * 1.2
          height: 133 * 1.2

          Text {
            width: parent.width
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: parent.index == 0 ? "主\n將" : "副\n將"
            lineHeight:65
            lineHeightMode: Text.FixedHeight
            font.family: "LiSu"
            font.pixelSize: 80
            color: '#444444'
          }

          GeneralCardItem {
            anchors.centerIn: parent
            dataModel: {
              const idx = root.dataModel.resultInt[parent.index]
              if (idx || idx === 0) {
                return root.dataModel.generalDict[idx]
              }
              return Ltk.createGeneralCardModel("caocao")
            }
            visible: root.dataModel.resultInt[parent.index] || root.dataModel.resultInt[parent.index] === 0
            selectable: true
            scale: 1.2
            onClicked: {}
          }
        }
      }
    }

    Flickable {
      width: parent.width - 20
      height: kingdomArea.realWidth > 0 ? 50 : 0
      anchors.horizontalCenter: parent.horizontalCenter
      contentWidth: kingdomArea.width + 6
      clip: true

      Row {
        id: kingdomArea
        x: 3
        y: realWidth > 0 ? 0 : -50
        width: realWidth
        height: 50
        spacing: 8

        property real realWidth: 0

        Repeater {
          id: kingdomButtonRepeater
          model: root.dataModel.kingdoms
          onModelChanged: kingdomArea.adjustPosition()

          Game.BasicItem {
            id: kingdomIcon
            height: childrenRect.height
            width: childrenRect.width
            required property string modelData
            property bool hovered
            Rectangle {
              width: 46; height: 46
              radius: 23
              color: '#2b2017'
              border.width: parent.selected ? 4 : 2
              border.color: parent.hovered ? "white" : (parent.selected ? '#eed43e' :'#4b3422')
            }
            Image {
              id: kingdomImage
              width: 50; height: 50
              source: {
                const ret = SkinBank.getGeneralCardDir(parent.modelData) + parent.modelData;
                if (Backend.exists(ret + ".png")) return ret;
                return ""
              }
            }
            HoverHandler {
              cursorShape: parent.selectable ? Qt.PointingHandCursor : Qt.ArrowCursor
              onHoveredChanged: {
                if (hovered && parent.selectable) {
                  parent.hovered = true;
                } else {
                  parent.hovered = false;
                }
              }
            }
            onClicked :{
              if (!selected) {
                root.dataModel.selectedKingdom = "";
              } else {
                root.dataModel.selectedKingdom = modelData;
                for (let i = 0; i < kingdomButtonRepeater.model.length; i++) {
                  const item = kingdomButtonRepeater.itemAt(i)
                  if (item !== this) item.selected = false;
                }
              }
            }
          }
        }

        Component.onCompleted: {
          adjustPosition()
        }

        Behavior on y {
          NumberAnimation {
            duration: 300
            easing.type: Easing.OutQuad
          }
        }

        function adjustPosition() {
          realWidth = (kingdomButtonRepeater.model.length * 58) - (kingdomButtonRepeater.model.length > 1 ? 8 : 0);
          if ((realWidth + 3) < parent.width) {
            x = (rightArea.width - 20 - realWidth)/2
          } else {
            x = 3
          }
          root.dataModel.selectedKingdom = ""
        }
      }

      Behavior on height {
        NumberAnimation {
          duration: 300
          easing.type: Easing.OutQuad
        }
      }
    }

    Row {
      id: buttonArea
      height: 45
      width: childrenRect.width
      spacing: 8
      anchors.horizontalCenter: parent.horizontalCenter

      MetroButton {
        id: convertBtn
        anchors.bottom: parent.bottom
        visible: !root.dataModel.convertDisabled
        enabled: root.dataModel.canConvert
        text: Lua.tr("Same General Convert")
        onClicked: {
          roomScene.showInfoPopup(
          Qt.createComponent("LunarLtk.Pages.InfoPopups", "SameConvert"),
          { dataModel: root.dataModel }
          );
        }
      }

      MetroButton {
        id: fightButton
        anchors.bottom: parent.bottom
        text: Lua.tr("OK")
        width: 120
        height: 35
        enabled: root.dataModel.newFeasible;

        onClicked: root.dataModel.accepted();
      }

      MetroButton {
        id: detailBtn
        anchors.bottom: parent.bottom
        enabled: root.dataModel.generalResult?.length > 0
        text: Lua.tr("Show General Detail")
        onClicked: roomScene.showInfoPopup(
        Qt.createComponent("LunarLtk.Pages.InfoPopups", "GeneralDetail"),
        { generals: root.dataModel.generalResult }
        );
      }
    }
  }

  ProgressBar {
    id: progress
    width: parent.width - 20
    height: 10
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 4
    from: 0.0
    to: 100.0

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
      from: (roomScene.dataModel.requestDuration / roomScene.dataModel.requestTotal) * 100.0;
      to: 0.0
      duration: roomScene.dataModel.requestDuration
    }
  }

  function arrangeCards() {
    for (let i = 0; i < dataModel.generalDict.length; i++) {
      let model = root.dataModel.generalDict[i];
      let item = generalCardList.itemAt(i)
      if (root.dataModel.resultInt.indexOf(i) === -1) {
        item.selected = false;
      } else {
        item.selected = true;
      }
    }
    // setHegemonyData();
  }

  function updateCompanion(gcard1, gcard2, overwrite) {
    if (Ltk.isCompanionWith(gcard1.modelData, gcard2.modelData)) {
      gcard1.dataModel.hasCompanion = true;
    } else if (overwrite) {
      gcard1.dataModel.hasCompanion = false;
    }
  }

  function setHegemonyData(){
    if (!root.dataModel || !root.dataModel.hegemony) return;

    let item, i;

    // 国战小标记
    const result = root.dataModel.resultInt ?? [];
    const selectedItem = result.slice(0, 2).map(idx => root.dataModel.generalDict[idx]?.dataModel);

    // 主副将认定
    for (i = 0; i < generalCardList.count; i++) {
      item = generalCardList.itemAt(i);
      item.dataModel.inPosition = 0;
    }
    if (selectedItem[0]) {
      if (selectedItem[0].dataModel.mainMaxHp !== 0) {
        selectedItem[0].dataModel.inPosition = 1;
      } else if (selectedItem[0].dataModel.deputyMaxHp !== 0) {
        selectedItem[0].dataModel.inPosition = -1;
      }
      if (selectedItem[1]) {
        if (selectedItem[1].dataModel.mainMaxHp !== 0) {
          selectedItem[1].dataModel.inPosition = -1;
        } else if (selectedItem[1].dataModel.deputyMaxHp !== 0) {
          selectedItem[1].dataModel.inPosition = 1;
        }
      }
    }

    // 珠联璧合
    for (i = 0; i < generalCardList.count; i++) {
      item = generalCardList.itemAt(i);

      if (selectedItem[0]) { // 有主将
        if (selectedItem[1]) { // 有副将
          if (selectedItem[0] === item) {
            updateCompanion(item, selectedItem[1], true);
          } else if (selectedItem[1] === item) {
            updateCompanion(item, selectedItem[0], true);
          } else {
            item.dataModel.hasCompanion = false;
          }
        } else {
          if (selectedItem[0] !== item) {
            updateCompanion(item, selectedItem[0], true);
          } else {
            for (let j = 0; j < generalCardList.count; j++) {
              updateCompanion(item, generalCardList.itemAt(j), false);
            }
          }
        }
      } else {
        for (let j = 0; j < generalCardList.count; j++) {
          updateCompanion(item, generalCardList.itemAt(j), false);
        }
      }
    }
  }

}
