import QtQuick 2.15
import QtQuick.Layouts 1.1


GraphicsBox {
  signal cardSelected(int cid)

  id: root
  title.text: Backend.translate("$ChooseCard")
  //@to-do: Adjust the UI design in case there are more than 7 cards
  width: 70 + Math.min(7, Math.max(1, handcards.count, equips.count, delayedTricks.count)) * 100
  height: 50 + (handcards.count > 0 ? 150 : 0) + (equips.count > 0 ? 150 : 0) + (delayedTricks.count > 0 ? 150 : 0)

  ListModel {
    id: handcards
  }

  ListModel {
    id: equips
  }

  ListModel {
    id: delayedTricks
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.topMargin: 40
    anchors.leftMargin: 20
    anchors.rightMargin: 20
    anchors.bottomMargin: 20

    Row {
      height: 130
      spacing: 15
      visible: handcards.count > 0

      Rectangle {
        border.color: "#A6967A"
        radius: 5
        color: "transparent"
        width: 18
        height: parent.height

        Text {
          color: "#E4D5A0"
          text: Backend.translate("$Hand")
          anchors.fill: parent
          wrapMode: Text.WrapAnywhere
          verticalAlignment: Text.AlignVCenter
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 15
        }
      }

      Row {
        spacing: 7
        Repeater {
          model: handcards

          CardItem {
            name: "card-back"
            cid: -1
            suit: ""
            number: 0
            autoBack: false
            selectable: true
            onClicked: root.cardSelected(cid);
          }
        }
      }
    }

    Row {
      height: 130
      spacing: 15
      visible: equips.count > 0

      Rectangle {
        border.color: "#A6967A"
        radius: 5
        color: "transparent"
        width: 18
        height: parent.height

        Text {
          color: "#E4D5A0"
          text: Backend.translate("$Equip")
          anchors.fill: parent
          wrapMode: Text.WrapAnywhere
          verticalAlignment: Text.AlignVCenter
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 15
        }
      }

      Row {
        spacing: 7
        Repeater {
          model: equips

          CardItem {
            cid: model.cid
            name: model.name
            suit: model.suit
            number: model.number
            autoBack: false
            selectable: true
            onClicked: root.cardSelected(cid);
          }
        }
      }
    }

    Row {
      height: 130
      spacing: 15
      visible: delayedTricks.count > 0

      Rectangle {
        border.color: "#A6967A"
        radius: 5
        color: "transparent"
        width: 18
        height: parent.height

        Text {
          color: "#E4D5A0"
          text: Backend.translate("$Judge")
          anchors.fill: parent
          wrapMode: Text.WrapAnywhere
          verticalAlignment: Text.AlignVCenter
          horizontalAlignment: Text.AlignHCenter
          font.pixelSize: 15
        }
      }

      Row {
        spacing: 7
        Repeater {
          model: delayedTricks

          CardItem {
            cid: model.cid
            name: model.name
            suit: model.suit
            number: model.number
            autoBack: false
            selectable: true
            onClicked: root.cardSelected(cid);
          }
        }
      }
    }
  }

  onCardSelected: finished();

  function addHandcards(cards)
  {
    if (cards instanceof Array) {
      for (var i = 0; i < cards.length; i++)
        handcards.append(cards[i]);
    } else {
      handcards.append(cards);
    }
  }

  function addEquips(cards)
  {
    if (cards instanceof Array) {
      for (var i = 0; i < cards.length; i++)
        equips.append(cards[i]);
    } else {
      equips.append(cards);
    }
  }

  function addDelayedTricks(cards)
  {
    if (cards instanceof Array) {
      for (var i = 0; i < cards.length; i++)
        delayedTricks.append(cards[i]);
    } else {
      delayedTricks.append(cards);
    }
  }
}
