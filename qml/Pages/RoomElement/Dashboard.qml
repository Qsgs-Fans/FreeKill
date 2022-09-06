import QtQuick 2.15
import QtQuick.Layouts 1.1
import QtGraphicalEffects 1.0

RowLayout {
  id: root

  property alias self: selfPhoto
  property alias handcardArea: handcardAreaItem
  property alias equipArea: selfPhoto.equipArea
  property alias delayedTrickArea: selfPhoto.delayedTrickArea
  property alias specialArea: selfPhoto.specialArea

  property bool selected: selfPhoto.selected

  property bool is_pending: false
  property string pending_skill: ""
  property var pending_card
  property var pendings: [] // int[], store cid
  property int selected_card: -1

  property alias skillButtons: skillPanel.skill_buttons

  property var expanded_piles: ({}) // name -> int[]

  signal cardSelected(var card)

  Item { width: 5 }

  HandcardArea {
    id: handcardAreaItem
    Layout.fillWidth: true
    Layout.preferredHeight: 130
    Layout.alignment: Qt.AlignVCenter
    onWidthChanged: updateCardPosition(true);
  }

  SkillArea {
    Layout.fillHeight: true
    Layout.fillWidth: true
    Layout.maximumWidth: width
    Layout.maximumHeight: height
    Layout.alignment: Qt.AlignBottom
    Layout.bottomMargin: 24
    id: skillPanel
  }

  Photo {
    id: selfPhoto
    handcards: handcardAreaItem.length
  }

  Item { width: 5 }

  Connections {
    target: handcardAreaItem
    function onCardSelected(cardId, selected) {
      dashboard.selectCard(cardId, selected);
    }
  }

  function disableAllCards() {
    handcardAreaItem.enableCards([]);
  }

  function unSelectAll(expectId) {
    handcardAreaItem.unselectAll(expectId);
  }

  function expandPile(pile) {
    let expanded_pile_names = Object.keys(expanded_piles);
    if (expanded_pile_names.indexOf(pile) !== -1)
      return;

    let component = Qt.createComponent("CardItem.qml");
    let parentPos = roomScene.mapFromItem(selfPhoto, 0, 0);

    // FIXME: only expand equip area here. modify this if need true pile
    expanded_piles[pile] = [];
    if (pile === "_equip") {
      let equips = selfPhoto.equipArea.getAllCards();
      equips.forEach(data => {
        data.x = parentPos.x;
        data.y = parentPos.y;
        let card = component.createObject(roomScene, data);
        handcardAreaItem.add(card);
      })
      handcardAreaItem.updateCardPosition();
    }
  }

  function retractPile(pile) {
    let expanded_pile_names = Object.keys(expanded_piles);
    if (expanded_pile_names.indexOf(pile) === -1)
      return;

    let parentPos = roomScene.mapFromItem(selfPhoto, 0, 0);

    delete expanded_piles[pile];
    if (pile === "_equip") {
      let equips = selfPhoto.equipArea.getAllCards();
      equips.forEach(data => {
        let card = handcardAreaItem.remove([data.cid])[0];
        card.origX = parentPos.x;
        card.origY = parentPos.y;
        card.destroyOnStop();
        card.goBack(true);
      })
      handcardAreaItem.updateCardPosition();
    }
  }

  function enableCards() {
    // TODO: expand pile
    let ids = [], cards = handcardAreaItem.cards;
    for (let i = 0; i < cards.length; i++) {
      if (JSON.parse(Backend.callLuaFunction("CanUseCard", [cards[i].cid, Self.id])))
        ids.push(cards[i].cid);
    }
    handcardAreaItem.enableCards(ids)
  }

  function selectCard(cardId, selected) {
    if (pending_skill !== "") {
      if (selected) {
        pendings.push(cardId);
      } else {
        pendings.splice(pendings.indexOf(cardId), 1);
      }

      updatePending();
    } else {
      if (selected) {
        handcardAreaItem.unselectAll(cardId);
        selected_card = cardId;
      } else {
        handcardAreaItem.unselectAll();
        selected_card = -1;
      }
      cardSelected(selected_card);
    }
  }

  function getSelectedCard() {
    if (pending_skill !== "") {
      return JSON.stringify({
        skill: pending_skill,
        subcards: pendings
      });
    } else {
      return selected_card;
    }
  }

  function updatePending() {
    if (pending_skill === "") return;

    let enabled_cards = [];

    handcardAreaItem.cards.forEach(function(card) {
      if (card.selected || Router.vs_view_filter(pending_skill, pendings, card.cid))
        enabled_cards.push(card.cid);
    });
    handcardAreaItem.enableCards(enabled_cards);

    let equip;
    for (let i = 0; i < 5; i++) {
      equip = equipAreaItem.equips.itemAt(i);
      if (equip.selected || equip.cid !== -1 &&
        Router.vs_view_filter(pending_skill, pendings, equip.cid))
        enabled_cards.push(equip.cid);
    }
    equipAreaItem.enableCards(enabled_cards);

    if (Router.vs_can_view_as(pending_skill, pendings)) {
      pending_card = {
        skill: pending_skill,
        subcards: pendings
      };
      cardSelected(JSON.stringify(pending_card));
    } else {
      pending_card = -1;
      cardSelected(pending_card);
    }
  }

  function startPending(skill_name) {
    pending_skill = skill_name;
    pendings = [];
    handcardAreaItem.unselectAll();

    // TODO: expand pile

    // TODO: equipment

    updatePending();
  }

  function deactivateSkillButton() {
    for (let i = 0; i < skillButtons.count; i++) {
      skillButtons.itemAt(i).pressed = false;
    }
  }

  function stopPending() {
    pending_skill = "";
    pending_card = -1;

    // TODO: expand pile

    let equip;
    for (let i = 0; i < 5; i++) {
      equip = equipAreaItem.equips.itemAt(i);
      if (equip.name !== "") {
        equip.selected = false;
        equip.selectable = false;
      }
    }

    pendings = [];
    handcardAreaItem.adjustCards();
    cardSelected(-1);
  }

  function addSkill(skill_name) {
    skillPanel.addSkill(skill_name);
  }

  function loseSkill(skill_name) {
    skillPanel.loseSkill(skill_name);
  }
}
