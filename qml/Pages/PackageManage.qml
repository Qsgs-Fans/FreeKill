import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  Button {
    text: qsTr("Quit")
    anchors.right: parent.right
    onClicked: {
      mainStack.pop();
    }
  }

  Component {
    id: packageDelegate

    Item {
      height: 22
      width: packageList.width

      RowLayout {
        anchors.fill: parent
        spacing: 16
        Text {
          font.pixelSize: 20
          text: pkgName
        }

        Text {
          font.pixelSize: 20
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: pkgURL
        }

        Text {
          font.pixelSize: 20
          text: pkgVersion
        }

        Text {
          font.pixelSize: 20
          color: pkgEnabled === "1" ? "green" : "red"
          text: pkgEnabled === "1" ? qsTr("Enabled") : qsTr("Disabled")
        }
      }

      TapHandler {
        onTapped: {
          if (packageList.currentIndex === index) {
            packageList.currentIndex = -1;
          } else {
            packageList.currentIndex = index;
          }
        }
      }
    }
  }

  ListModel {
    id: packageModel
  }

  ColumnLayout {
    anchors.fill: parent

  RowLayout {
    Layout.fillHeight: true
    Layout.alignment: Qt.AlignHCenter
    Item {
      Layout.preferredWidth: root.width * 0.9
      Layout.fillHeight: true
      Rectangle {
        anchors.fill: parent
        color: "#88EEEEEE"
      }
      ListView {
        id: packageList
        anchors.fill: parent

        contentHeight: packageDelegate.height * count
        ScrollBar.vertical: ScrollBar {}
        header: RowLayout {
          height: 22
          width: packageList.width
          spacing: 16
          Text {
            font.pixelSize: 20
            text: qsTr("Name")
          }

          Text {
            font.pixelSize: 20
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "URL"
          }

          Text {
            font.pixelSize: 20
            text: qsTr("Version")
          }

          Text {
            font.pixelSize: 20
            text: qsTr("Enable")
          }
        }
        delegate: packageDelegate
        model: packageModel
        highlight: Rectangle { color: "lightsteelblue"; radius: 5 }
        Component.onCompleted: { currentIndex = -1; }
      }
    }

    ColumnLayout {
      Button {
        enabled: packageList.currentItem
        text: qsTr("Enable")
        onClicked: {
          let idx = packageList.currentIndex;
          let name = packageModel.get(idx).pkgName;
          Pacman.enablePack(name);
          updatePackageList();
          packageList.currentIndex = idx;
        }
      }
      Button {
        enabled: packageList.currentItem
        text: qsTr("Disable")
        onClicked: {
          let idx = packageList.currentIndex;
          let name = packageModel.get(idx).pkgName;
          Pacman.disablePack(name);
          updatePackageList();
          packageList.currentIndex = idx;
        }
      }
      Button {
        enabled: packageList.currentItem
        text: qsTr("Upgrade")
        onClicked: {
          let idx = packageList.currentIndex;
          let name = packageModel.get(idx).pkgName;
          Pacman.upgradePack(name);
          updatePackageList();
          packageList.currentIndex = idx;
        }
      }
      Button {
        enabled: packageList.currentItem
        text: qsTr("Remove")
        onClicked: {
          let idx = packageList.currentIndex;
          let name = packageModel.get(idx).pkgName;
          Pacman.removePack(name);
          updatePackageList();
          packageList.currentIndex = idx;
        }
      }
      Button {
        enabled: packageList.currentItem
        text: qsTr("Copy URL")
        onClicked: {
          let idx = packageList.currentIndex;
          let name = packageModel.get(idx).pkgURL;
          Backend.copyToClipboard(name);
          toast.show(qsTr("Copied."));
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    TextField {
      id: urlEdit
      Layout.fillWidth: true
      clip: true
    }

    Button {
      text: qsTr("Install From URL")
      enabled: urlEdit.text !== ""
      onClicked: {
        let url = urlEdit.text;
        mainWindow.busy = true;
        Pacman.downloadNewPack(url, true);
      }
    }
  }

  }

  function updatePackageList() {
    packageModel.clear();
    let data = JSON.parse(Pacman.listPackages());
    data.forEach(e => packageModel.append({
      pkgName: e.name,
      pkgURL: e.url,
      pkgVersion: e.hash.substring(0, 8),
      pkgEnabled: e.enabled
    }));
  }

  function downloadComplete() {
    let idx = packageList.currentIndex;
    updatePackageList();
    packageList.currentIndex = idx;
  }

  Component.onCompleted: {
    updatePackageList();
  }
}
