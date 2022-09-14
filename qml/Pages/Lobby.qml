import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Layouts
import "Logic.js" as Logic

Item {
  id: root
  property alias roomModel: roomModel
  Component {
    id: roomDelegate

    Item {
      height: 18
      width: roomList.width

      Rectangle {
        anchors.fill: parent
        color: "white"
        opacity: 0
        radius: 2
        Behavior on opacity {
          NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: parent.opacity = 1;
          onExited: parent.opacity = 0;
          onClicked: {
            mainWindow.busy = true;
            ClientInstance.notifyServer(
              "EnterRoom",
              JSON.stringify([roomId])
            );
          }
        }
      }

      RowLayout {
        anchors.fill: parent
        spacing: 16
        Text {
          text: roomId
        }

        Text {
          horizontalAlignment: Text.AlignHCenter
          Layout.fillWidth: true
          text: roomName
        }

        Text {
          text: gameMode
        }

        Text {
          color: (playerNum == capacity) ? "red" : "black"
          text: playerNum + "/" + capacity
        }
      }
    }
  }

  ListModel {
    id: roomModel
  }

  RowLayout {
    anchors.fill: parent
    Item {
      Layout.preferredWidth: root.width * 0.7
      Layout.fillHeight: true
      Rectangle {
        width: parent.width * 0.8
        height: parent.height * 0.8
        anchors.centerIn: parent
        color: "#88888888"
        radius: 16
        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: Backend.translate("Room List")
        }
        ListView {
          id: roomList
          height: parent.height * 0.9
          width: parent.width * 0.95
          contentHeight: roomDelegate.height * count
          ScrollBar.vertical: ScrollBar {}
          anchors.centerIn: parent
          delegate: roomDelegate
          model: roomModel
        }
      }
    }

    ColumnLayout {
      Button {
        text: Backend.translate("Edit Profile")
        onClicked: {
          globalPopup.source = "EditProfile.qml";
          globalPopup.open();
        }
      }
      Button {
        text: Backend.translate("Create Room")
        onClicked: {
          globalPopup.source = "CreateRoom.qml";
          globalPopup.open();
        }
      }
      Button {
        text: Backend.translate("Generals Overview")
        onClicked: {
          mainStack.push(mainWindow.generalsOverviewPage);
          mainStack.currentItem.loadPackages();
        }
      }
      Button {
        text: Backend.translate("Cards Overview")
        onClicked: {
          mainStack.push(mainWindow.cardsOverviewPage);
          mainStack.currentItem.loadPackages();
        }
      }
      Button {
        text: Backend.translate("Scenarios Overview")
      }
      Button {
        text: Backend.translate("About")
      }
      Button {
        text: Backend.translate("Exit Lobby")
        onClicked: {
          toast.show("Goodbye.");
          Backend.quitLobby();
          mainStack.pop();
        }
      }
    }
  }

  Loader {
    id: lobby_dialog
    z: 1000
    onSourceChanged: {
      if (item === null)
        return;
      item.finished.connect(function(){
        source = "";
      });
      item.widthChanged.connect(function(){
        lobby_dialog.moveToCenter();
      });
      item.heightChanged.connect(function(){
        lobby_dialog.moveToCenter();
      });
      moveToCenter();
    }

    function moveToCenter()
    {
      item.x = Math.round((root.width - item.width) / 2);
      item.y = Math.round(root.height * 0.67 - item.height / 2);
    }
  }

  Component.onCompleted: {
    toast.show(Backend.translate("$WelcomeToLobby"));
  }
}

