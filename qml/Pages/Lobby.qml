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
      height: 22
      width: roomList.width

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

        Text {
          text: Backend.translate("Enter")
          font.pixelSize: 24
          MouseArea {
            anchors.fill: parent
            onClicked: {
              config.observing = false;
              mainWindow.busy = true;
              ClientInstance.notifyServer(
                "EnterRoom",
                JSON.stringify([roomId])
              );
            }
          }
        }

        Text {
          text: Backend.translate("Observe")
          font.pixelSize: 24
          MouseArea {
            anchors.fill: parent
            onClicked: {
              config.observing = true;
              mainWindow.busy = true;
              ClientInstance.notifyServer(
                "ObserveRoom",
                JSON.stringify([roomId])
              );
            }
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
    Item {
      Layout.preferredWidth: root.width * 0.6
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

    GridLayout {
      flow: GridLayout.TopToBottom
      rows: 4
      TileButton {
        iconSource: "configure"
        text: Backend.translate("Edit Profile")
        onClicked: {
          lobby_dialog.source = "LobbyElement/EditProfile.qml";
          lobby_drawer.open();
        }
      }
      TileButton {
        iconSource: "create_room"
        text: Backend.translate("Create Room")
        onClicked: {
          lobby_dialog.source = "LobbyElement/CreateRoom.qml";
          lobby_drawer.open();
          config.observing = false;
        }
      }
      TileButton {
        iconSource: "general_overview"
        text: Backend.translate("Generals Overview")
        onClicked: {
          mainStack.push(mainWindow.generalsOverviewPage);
          mainStack.currentItem.loadPackages();
        }
      }
      TileButton {
        iconSource: "card_overview"
        text: Backend.translate("Cards Overview")
        onClicked: {
          mainStack.push(mainWindow.cardsOverviewPage);
          mainStack.currentItem.loadPackages();
        }
      }
      TileButton {
        iconSource: "rule_summary"
        text: Backend.translate("Scenarios Overview")
      }
      TileButton {
        iconSource: "replay"
        text: Backend.translate("Replay")
      }
      TileButton {
        iconSource: "about"
        text: Backend.translate("About")
        onClicked: {
          mainStack.push(mainWindow.aboutPage);
        }
      }
      TileButton {
        iconSource: "quit"
        text: Backend.translate("Exit Lobby")
        onClicked: {
          toast.show("Goodbye.");
          Backend.quitLobby();
          mainStack.pop();
        }
      }
    }
  }

  Drawer {
    id: lobby_drawer
    width: parent.width * 0.4 / mainWindow.scale
    height: parent.height / mainWindow.scale
    dim: false
    clip: true
    dragMargin: 0
    scale: mainWindow.scale
    transformOrigin: Item.TopLeft

    Loader {
      id: lobby_dialog
      anchors.fill: parent
      onSourceChanged: {
        if (item === null)
          return;
        item.finished.connect(() => {
          source = "";
          lobby_drawer.close();
        });
      }
    }
  }

  Component.onCompleted: {
    toast.show(Backend.translate("$WelcomeToLobby"));
  }
}

