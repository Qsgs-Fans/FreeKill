import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Layouts
import "LobbyElement"
import "Common"
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
          TapHandler {
            onTapped: {
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
          TapHandler {
            onTapped: {
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

  PersonalSettings {
  }

  RowLayout {
    anchors.centerIn: parent
    width: childrenRect.width
    height: parent.height
    Item {
      Layout.preferredWidth: root.width * 0.6
      Layout.fillHeight: true
      Rectangle {
        width: parent.width * 0.8
        height: parent.height * 0.8
        anchors.centerIn: parent
        color: "#88EEEEEE"
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
  }

  Button {
    anchors.bottom: buttonRow.top
    anchors.right: parent.right
    width: 120
    display: AbstractButton.TextUnderIcon
    icon.name: "media-playback-start"
    text: Backend.translate("Create Room")
    onClicked: {
      lobby_dialog.source = "LobbyElement/CreateRoom.qml";
      lobby_drawer.open();
      config.observing = false;
    }
  }

  RowLayout {
    id: buttonRow
    anchors.right: parent.right
    anchors.bottom: parent.bottom
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
      onClicked: {
        mainStack.push(mainWindow.modesOverviewPage);
      }
    }
    Button {
      text: Backend.translate("Replay")
    }
    Button {
      text: Backend.translate("About")
      onClicked: {
        mainStack.push(mainWindow.aboutPage);
      }
    }
  }

  Button {
    anchors.right: parent.right
    text: Backend.translate("Exit Lobby")
    display: AbstractButton.TextBesideIcon
    icon.name: "application-exit"
    onClicked: {
      toast.show("Goodbye.");
      Backend.quitLobby();
      mainStack.pop();
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

  property int lobbyPlayerNum: 0
  property int serverPlayerNum: 0

  function updateOnlineInfo() {
  }

  onLobbyPlayerNumChanged: updateOnlineInfo();
  onServerPlayerNumChanged: updateOnlineInfo();

  Rectangle {
    id: info
    color: "#88EEEEEE"
    width: childrenRect.width + 8
    height: childrenRect.height + 4
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    radius: 4

    Text {
      x: 4; y: 2
      font.pixelSize: 16
      text: Backend.translate("$OnlineInfo")
        .arg(lobbyPlayerNum).arg(serverPlayerNum) + "\n"
        + "Powered by FreeKill " + FkVersion
    }
  }

  ChatBox {
    id: lobbyChat
    anchors.bottom: info.top
    width: info.width
    height: root.height * 0.6
    isLobby: true
    color: "#88EEEEEE"
    radius: 4
  }

  function addToChat(pid, raw, msg) {
    if (raw.type !== 1) return;
    lobbyChat.append(msg);
    toast.show("<b>" + raw.userName + "</b>: " + raw.msg);
  }

  Component.onCompleted: {
    toast.show(Backend.translate("$WelcomeToLobby"));
  }
}

