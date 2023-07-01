import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  property var mod: ({})
  property string modName
  property string modPath: "mymod/" + modName + "/"

  onModNameChanged: {
    mod = JSON.parse(ModBackend.readFile(modPath + "mod.json"));
  }

  ToolBar {
    id: bar
    width: parent.width
    RowLayout {
      anchors.fill: parent
      ToolButton {
        icon.source: AppPath + "/image/modmaker/back"
        onClicked: modStack.pop();
      }
      Label {
        text: qsTr("ModMaker") + " - " + modName
        horizontalAlignment: Qt.AlignHCenter
        Layout.fillWidth: true
      }
      ToolButton {
        icon.source: AppPath + "/image/modmaker/menu"
        onClicked: {
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

    ListView {
      anchors.fill: parent
      model: mod.packages ?? []
      delegate: SwipeDelegate {
        width: root.width
        text: modelData

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

          SwipeDelegate.onClicked: deletePackage(modelData);

          background: Rectangle {
            color: deleteLabel.SwipeDelegate.pressed ? Qt.darker("tomato", 1.1) : "tomato"
          }
        }
      }
    }
  }

  RoundButton {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 40
    scale: 2
    icon.source: AppPath + "/image/modmaker/add"
    onClicked: {
      dialog.source = "CreateSomething.qml";
      dialog.item.head = "create_package";
      dialog.item.hint = "create_package_hint";
      drawer.open();
      dialog.item.accepted.connect((name) => {
        createNewPackage(name);
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

  function createNewPackage(name) {
    const new_name = modName + "_" + name;
    mod.packages = mod.packages ?? [];
    if (mod.packages.indexOf(new_name) !== -1) {
      toast.show(qsTr("cannot use this package name"));
      return;
    }
    const path = modPath + new_name + "/";
    ModBackend.mkdir(path);
    mod.packages.push(new_name);
    ModBackend.saveToFile(modPath + "mod.json", JSON.stringify(mod, undefined, 2));
    const pkgInfo = {
      name: new_name,
    };
    ModBackend.saveToFile(path + "pkg.json", JSON.stringify(pkgInfo, undefined, 2));
    root.modChanged();
  }

  function deletePackage(name) {
    const path = modPath + name + "/";
    ModBackend.rmrf(path);
    mod.packages.splice(mod.packages.indexOf(name), 1);
    ModBackend.saveToFile(modPath + "mod.json", JSON.stringify(mod, undefined, 2));
    root.modChanged();
  }
}
