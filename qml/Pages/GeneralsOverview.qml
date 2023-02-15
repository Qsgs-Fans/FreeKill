import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "RoomElement"

Item {
  id: root

  property bool loaded: false

  ListView {
    width: Math.floor(root.width / 98) * 98
    height: parent.height
    anchors.centerIn: parent
    ScrollBar.vertical: ScrollBar {}
    model: ListModel {
      id: packages
    }

    delegate: ColumnLayout {
      Text { text: Backend.translate(name) }
      GridLayout {
        columns: root.width / 98
        Repeater {
          model: JSON.parse(Backend.callLuaFunction("GetGenerals", [name]))
          GeneralCardItem { 
            autoBack: false
            name: modelData
            onClicked: {
              generalText.clear();
              generalText.general = modelData;
              generalDetail.open();
            }
          }
        }
      }
    }
  }

  Button {
    text: Backend.translate("Quit")
    anchors.right: parent.right
    onClicked: {
      mainStack.pop();
    }
  }

  Drawer {
    id: generalDetail
    edge: Qt.RightEdge
    width: parent.width * 0.4 / mainWindow.scale
    height: parent.height / mainWindow.scale
    dim: false
    clip: true
    dragMargin: 0
    scale: mainWindow.scale
    transformOrigin: Item.TopRight

    Flickable {
      flickableDirection: Flickable.VerticalFlick
      contentWidth: generalText.width
      contentHeight: generalText.height
      width: parent.width * 0.8
      height: parent.height * 0.8
      clip: true
      anchors.centerIn: parent
      ScrollBar.vertical: ScrollBar {}

      TextEdit {
        id: generalText

        property string general: ""
        width: generalDetail.width * 0.75
        readOnly: true
        selectByKeyboard: true
        selectByMouse: true
        wrapMode: TextEdit.WordWrap
        textFormat: TextEdit.RichText
        font.pixelSize: 16

        onGeneralChanged: {
          let data = JSON.parse(Backend.callLuaFunction("GetGeneralDetail", [general]));
          this.append(Backend.translate(data.kingdom) + " " + Backend.translate(general) + " " + data.hp + "/" + data.maxHp);
          data.skill.forEach(t => {
            this.append("<b>" + Backend.translate(t.name) + "</b>: " + t.description)
          });
        }
      }
    }
  }

  function loadPackages() {
    if (loaded) return;
    let packs = JSON.parse(Backend.callLuaFunction("GetAllGeneralPack", []));
    packs.forEach((name) => packages.append({ name: name }));
    loaded = true;
  }
}
