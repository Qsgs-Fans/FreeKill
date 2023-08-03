// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Fk.RoomElement

Item {
  id: root

  property bool loaded: false

  Rectangle {
    anchors.fill: listView
    color: "#88EEEEEE"
    radius: 6
  }

  ListView {
    id: listView
    clip: true
    width: 130
    height: parent.height - 20
    y: 10
    ScrollBar.vertical: ScrollBar {}
    model: ListModel {
      id: packages
    }

    highlight: Rectangle { color: "#E91E63"; radius: 5 }
    highlightMoveDuration: 500

    delegate: Item {
      width: listView.width
      height: 40

      Text {
        text: Backend.translate(name)
        anchors.centerIn: parent
      }

      TapHandler {
        onTapped: {
          listView.currentIndex = index;
        }
      }
    }

    onCurrentIndexChanged: { vanishAnim.start(); }
  }

  GridView {
    id: gridView
    clip: true
    width: root.width - listView.width - cardDetail.width - 16
    height: parent.height - 20
    y: 10
    anchors.left: listView.right
    anchors.leftMargin: 8 + (width % 100) / 2
    cellHeight: 140
    cellWidth: 100

    delegate: CardItem {
      autoBack: false
      property int dupCount: 0

      Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: parent.dupCount ? ("x" + parent.dupCount.toString()) : ""
        font.pixelSize: 36
        color: "white"
        style: Text.Outline
      }

      Component.onCompleted: {
        const data = modelData;
        if (!data.cards) {
          name = data.name;
          suit = data.suit;
          number = data.number;
          cid = data.cid;
        } else {
          name = data.name;
          cid = data.cid;
          suit = "";
          number = 0;
          color = "";
          dupCount = data.cards.length;
        }
      }

      onClicked: {
        cardDetail.cid = modelData.cid;
        cardDetail.cards = modelData.cards;
        cardDetail.updateCard();
      }
    }
  }

  ParallelAnimation {
    id: vanishAnim
    PropertyAnimation {
      target: gridView
      property: "opacity"
      to: 0
      duration: 150
      easing.type: Easing.InOutQuad
    }
    PropertyAnimation {
      target: gridView
      property: "y"
      to: 30
      duration: 150
      easing.type: Easing.InOutQuad
    }
    onFinished: {
      const pkg = [listView.model.get(listView.currentIndex).name];
      const idList = JSON.parse(Backend.callLuaFunction("GetCards", pkg));
      const cardList = idList.map(id => JSON.parse(Backend.callLuaFunction
        ("GetCardData",[id])));

      const groupedCardList = [];
      let groupedCards = {};
      cardList.forEach(c => {
        const name = c.name;
        if (!groupedCards[name]) {
          groupedCardList.push(name);
          groupedCards[name] = [];
        }
        groupedCards[name].push({
          cid: c.cid,
          suit: c.suit,
          number: c.number,
        });
      });

      const model = [];
      groupedCardList.forEach(name => {
        const cards = groupedCards[name];
        if (cards.length === 1) {
          model.push({
            name: name,
            extension: pkg,
            suit: cards[0].suit,
            number: cards[0].number,
            cid: cards[0].cid,
          });
        } else {
          model.push({
            name: name,
            cid: cards[0].cid,
            cards: cards,
          })
        }
      });
      gridView.model = model;
      appearAnim.start();
    }
  }

  SequentialAnimation {
    id: appearAnim
    PauseAnimation { duration: 200 }
    ParallelAnimation {
      PropertyAnimation {
        target: gridView
        property: "opacity"
        to: 1
        duration: 150
        easing.type: Easing.InOutQuad
      }
      PropertyAnimation {
        target: gridView
        property: "y"
        from: 20
        to: 10
        duration: 150
        easing.type: Easing.InOutQuad
      }
    }
  }

  Rectangle {
    id: cardDetail
    width: 310
    height: parent.height - 20
    y: 10
    anchors.right: parent.right
    anchors.rightMargin: 10
    color: "#88EEEEEE"
    radius: 8

    property int cid: 1
    property var cards
    function updateCard() {
      const data = JSON.parse(Backend.callLuaFunction("GetCardData", [cid]));
      const suitTable = {
        spade: "♠", heart: '<font color="red">♥</font>',
        club: "♣", diamond: '<font color="red">♦</font>',
      }
      const getNumString = n => {
        switch (n) {
          case 1:
            return "A";
          case 11:
            return "J";
          case 12:
            return "Q";
          case 13:
            return "K";
          default:
            return n.toString();
        }
      }

      if (!cards) {
        detailCard.setData(data);
        detailCard.dupCount = 0;
      } else {
        detailCard.cid = cid;
        detailCard.color = "";
        detailCard.suit = "";
        detailCard.number = 0;
        detailCard.dupCount = cards.length;
      }
      detailCard.known = true;
      cardText.clear();
      cardText.append(Backend.translate(":" + data.name));

      const skills = JSON.parse(Backend.callLuaFunction
        ("GetCardSpecialSkills", [cid]));
      if (skills.length > 0) {
        cardText.append("<br/>" + Backend.translate("Special card skills:"));
        skills.forEach(t => {
          cardText.append("<b>" + Backend.translate(t) + "</b>: "
            + Backend.translate(":" + t));
        });
      }

      if (cards) {
        cardText.append("<br/>" + Backend.translate("Every suit & number:"));
        cardText.append(cards.map(c => {
          return (suitTable[c.suit] + getNumString(c.number))
        }).join(", "));
      }
    }

    Flickable {
      flickableDirection: Flickable.VerticalFlick
      contentHeight: detailLayout.height
      width: parent.width - 40
      height: parent.height - 40
      clip: true
      anchors.centerIn: parent
      ScrollBar.vertical: ScrollBar {}

      ColumnLayout {
        id: detailLayout
        width: parent.width

        CardItem {
          id: detailCard
          Layout.alignment: Qt.AlignHCenter
          cid: 1
          known: false

          property int dupCount: 0
          Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: parent.dupCount ? ("x" + parent.dupCount.toString()) : ""
            font.pixelSize: 36
            color: "white"
            style: Text.Outline
          }
        }

        TextEdit {
          id: cardText

          Layout.fillWidth: true
          readOnly: true
          selectByKeyboard: true
          selectByMouse: false
          wrapMode: TextEdit.WordWrap
          textFormat: TextEdit.RichText
          font.pixelSize: 16
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

  function loadPackages() {
    if (loaded) return;
    const packs = JSON.parse(Backend.callLuaFunction("GetAllCardPack", []));
    packs.forEach(name => {
      if (!config.serverHiddenPacks.includes(name)) {
        packages.append({ name: name });
      }
    });
    loaded = true;
  }
}
