// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import Fk
import Fk.Widgets as W
import Fk.Components.LunarLTK

W.PageBase {
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
        text: Lua.tr(name)
        anchors.centerIn: parent
      }

      W.TapHandler {
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
      showDetail: false
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
      const pkg = listView.model.get(listView.currentIndex).name;
      const idList = Lua.call("GetCards", pkg);
      const cardList = idList.map(id => Lua.call("GetCardData", id));

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
      const data = Lua.call("GetCardData", cid);
      detailFlickable.contentY = 0; // 重置滚动条
      const suitTable = {
        spade: "♠", heart: '<font color="red">♥</font>',
        club: "♣", diamond: '<font color="red">♦</font>',
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
      cardText.clearSavedText();
      audioRow.clear();
      cardText.append(Lua.tr(":" + data.name));
      addCardAudio(data)
      const skills = Lua.call("GetCardSpecialSkills", cid);
      if (skills.length > 0) {
        cardText.append("<br/>" + Lua.tr("Special card skills:"));
        skills.forEach(t => {
          cardText.append("<b>" + Lua.tr(t) + "</b>: "
            + Lua.tr(":" + t));
        });
      }

      if (cards) {
        cardText.append("<br/>" + Lua.tr("Every suit & number:"));
        cardText.append(cards.map(c => {
          return (suitTable[c.suit] + Util.convertNumber(c.number))
        }).join(", "));
      }
    }

    Flickable {
      id: detailFlickable
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
          showDetail: false

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

          property var savedtext: []
          function clearSavedText() {
            savedtext = [];
          }
          Layout.fillWidth: true
          readOnly: true
          selectByKeyboard: true
          selectByMouse: false
          wrapMode: TextEdit.WordWrap
          textFormat: TextEdit.RichText
          font.pixelSize: 16
          onLinkActivated: (link) => {
            if (link === "back") {
              text = savedtext.pop();
            } else {
              savedtext.push(text);
              text = '<a href="back">' + Lua.tr("Click to back") + '</a><br>' + Lua.tr(link);
            }
          }
        }

        GridLayout {
          columns: 2
          Repeater {
            model: ListModel {
              id: audioRow
            }
            Button {
              Layout.fillWidth: true
              contentItem: Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: {
                  if (audioType === "male") {
                    return Lua.tr("Male Audio");
                  } else if (audioType === "female") {
                    return Lua.tr("Female Audio");
                  } else if (audioType === "equip_effect")  {
                    return Lua.tr("Equip Effect Audio");
                  } {
                    return Lua.tr("Equip Use Audio");
                  }
                }
                font.pixelSize: 14
              }
              onClicked: {
                const data = Lua.call("GetCardData", cardDetail.cid);
                let path;
                if (audioType === "male" || audioType === "female") {
                  path = SkinBank.getAudio(data.name, extension, "card/" + audioType);
                } else if (audioType === "equip_effect") {
                  path = SkinBank.getAudio(data.name, extension, "card");
                } else {
                  Backend.playSound("./audio/card/common/" + extension);
                  return;
                }
                if (path) {
                  Backend.playSound(path);
                }
              }
            }
          }
        }
      }
    }
  }

  Button {
    text: Lua.tr("Quit")
    anchors.right: parent.right
    visible: root.parent instanceof StackView
    onClicked: {
      App.quitPage();
    }
  }

  function loadAudio(cardName, type, extension, orig_extension) {
    const prefix = AppPath + "/packages/";
    const suffix = cardName + ".mp3";
    let midfix = type + "/";
    if (type === "equip_effect") {
      midfix = "";
    }
    let fname = prefix + extension + "/audio/card/" + midfix + suffix;
    if (Backend.exists(fname)) {
      audioRow.append( { audioType: type, extension: extension } );
    } else {
      fname = prefix + orig_extension + "/audio/card/" + midfix + suffix;
      if (Backend.exists(fname)) {
        audioRow.append( { audioType: type, extension: orig_extension} );
      }
    }
  }

  function addCardAudio(card) {
    const extension = card.extension;
    const orig_extension = Lua.call("GetCardExtensionByName", card.name);
    loadAudio(card.name, "male", extension, orig_extension);
    loadAudio(card.name, "female", extension, orig_extension);
    if (audioRow.count === 0 && card.type === 3) {
      loadAudio(card.name, "equip_effect", extension, orig_extension);
      if (audioRow.count === 0) {
        let subType = "";
        if (card.subtype === "defensive_ride" || card.subtype === "offensive_ride") {
          subType = "horse";
        } else if (card.subtype === "weapon") {
          subType = "weapon";
        } else {
          subType = "armor";
        }
        audioRow.append( { audioType: "equip_use", extension: subType } );
      }
    }
  }

  function loadPackages() {
    if (loaded) return;
    const packs = Lua.call("GetAllCardPack");
    packs.forEach(name => {
      if (!Config.serverHiddenPacks.includes(name)) {
        packages.append({ name: name });
      }
    });
    loaded = true;
  }

  Component.onCompleted: {
    loadPackages();
  }
}
