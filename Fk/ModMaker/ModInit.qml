import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  property bool configOK: modConfig.userName !== "" && modConfig.email !== ""

  ToolBar {
    id: bar
    width: parent.width
    RowLayout {
      anchors.fill: parent
      ToolButton {
        icon.source: AppPath + "/image/modmaker/back"
        onClicked: mainStack.pop();
      }
      Label {
        text: qsTr("ModMaker")
        horizontalAlignment: Qt.AlignHCenter
        Layout.fillWidth: true
      }
      Button {
        text: "Test"
        onClicked: {
          const component = Qt.createComponent("Block/Workspace.qml");
          if (component.status !== Component.Ready) {
            return;
          }
          const page = component.createObject(null);
          modStack.push(page);
        }
      }
      ToolButton {
        icon.source: AppPath + "/image/modmaker/menu"
        onClicked: {
          dialog.source = "UserInfo.qml";
          drawer.open();
        }
      }
    }
  }

  Rectangle {
    width: parent.width
    height: parent.height - bar.height
    anchors.top: bar.bottom
    color: "snow"
    opacity: 0.75

    Text {
      anchors.centerIn: parent
      text: root.configOK ? "" : qsTr("config is incomplete")
    }

    ListView {
      anchors.fill: parent
      model: modConfig.modList
      clip: true
      delegate: SwipeDelegate {
        width: root.width
        text: modelData

        onClicked: {
          const component = Qt.createComponent("ModDetail.qml");
          if (component.status !== Component.Ready) {
            return;
          }
          const page = component.createObject(null, { modName: modelData });
          modStack.push(page);
        }

        swipe.right: Label {
          id: deleteLabel
          text: qsTr("Delete")
          color: "white"
          verticalAlignment: Label.AlignVCenter
          padding: 12
          height: parent.height
          anchors.right: parent.right
          opacity: swipe.complete ? 1 : 0
          Behavior on opacity { NumberAnimation { } }

          SwipeDelegate.onClicked: deleteMod(modelData);

          background: Rectangle {
            color: deleteLabel.SwipeDelegate.pressed ? Qt.darker("tomato", 1.1) : "tomato"
          }
        }
      }
    }
  }

  RoundButton {
    visible: root.configOK
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 40
    scale: 2
    icon.source: AppPath + "/image/modmaker/add"
    onClicked: {
      dialog.source = "CreateSomething.qml";
      dialog.item.head = "create_mod";
      dialog.item.hint = "create_mod_hint";
      drawer.open();
      dialog.item.accepted.connect((name) => {
        createNewMod(name);
      });
    }
  }

  Drawer {
    id: drawer
    width: parent.width * 0.4 / mainWindow.scale
    height: parent.height / mainWindow.scale
    dim: false
    clip: true
    dragMargin: 0
    scale: mainWindow.scale
    transformOrigin: Item.TopLeft

    Loader {
      id: dialog
      anchors.fill: parent
      onSourceChanged: {
        if (item === null)
          return;
        item.finished.connect(() => {
          sourceComponent = undefined;
          drawer.close();
        });
      }
      onSourceComponentChanged: sourceChanged();
    }
  }

  function createNewMod(name) {
    const banned = [ "test", "standard", "standard_cards", "maneuvering" ];
    if (banned.indexOf(name) !== -1 || modConfig.modList.indexOf(name) !== -1) {
      toast.show(qsTr("cannot use this mod name"));
      return;
    }
    ModBackend.createMod(name);
    const modInfo = {
      name: name,
      descrption: "",
      author: modConfig.userName,
    };
    ModBackend.saveToFile(`mymod/${name}/mod.json`, JSON.stringify(modInfo, undefined, 2));
    ModBackend.saveToFile(`mymod/${name}/.gitignore`, "init.lua");
    ModBackend.stageFiles(name);
    ModBackend.commitChanges(name, "Initial commit", modConfig.userName, modConfig.email);
    modConfig.addMod(name);
  }

  function deleteMod(name) {
    ModBackend.removeMod(name);
    modConfig.removeMod(name);
  }
}
