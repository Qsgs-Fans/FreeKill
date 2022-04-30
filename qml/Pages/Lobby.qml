import QtQuick 2.15
import QtQuick.Controls 2.0
import QtQuick.Window 2.0
import QtQuick.Layouts 1.15
import "Logic.js" as Logic

Item {
  id: root
  property alias roomModel: roomModel
  Component {
    id: roomDelegate

    RowLayout {
      width: roomList.width * 0.9
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

      Text {
        text: "Enter"
        font.underline: true
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: {  parent.color = "blue"   }
          onExited: { parent.color = "black"  }
          onClicked: {
            mainWindow.busy = true;
            ClientInstance.notifyServer(
              "EnterRoom",
              JSON.stringify([roomId])
            );
          }
        }
      }
    }
  }

  ListModel {
    id: roomModel
  }

  RowLayout {
    anchors.fill: parent
    Rectangle {
      Layout.preferredWidth: root.width * 0.7
      Layout.fillHeight: true
      color: "#e2e2e1"
      radius: 4
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "Room List"
      }
      ListView {
        height: parent.height * 0.9
        width: parent.width * 0.95
        contentHeight: roomDelegate.height * count
        ScrollBar.vertical: ScrollBar {}
        anchors.centerIn: parent
        id: roomList
        delegate: roomDelegate
        model: roomModel
      }
    }

    ColumnLayout {
      Button {
        text: "Edit Profile"
        onClicked: {
          globalPopup.source = "EditProfile.qml";
          globalPopup.open();
        }
      }
      Button {
        text: "Create Room"
        onClicked: {
          globalPopup.source = "CreateRoom.qml";
          globalPopup.open();
        }
      }
      Button {
        text: "Generals Overview"
        onClicked: {
          mainStack.push(generalsOverview);
          mainStack.currentItem.loadPackages();
        }
      }
      Button {
        text: "Cards Overview"
        onClicked: {
          mainStack.push(cardsOverview);
          mainStack.currentItem.loadPackages();
        }
      }
      Button {
        text: "Scenarios Overview"
      }
      Button {
        text: "About"
      }
      Button {
        text: "Exit Lobby"
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
    toast.show("Welcome to FreeKill lobby!");
  }
}

