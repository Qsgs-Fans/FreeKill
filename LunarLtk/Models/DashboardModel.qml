import QtQuick
import Fk
import LunarLtk

QtObject {
  id: root

  property list<CardModel> handcards: [];
  property list<CardModel> expandedCards: [];
  property list<int> visible_ids: [];

  property list<SkillModel> skills: [];
  property list<SkillModel> fakeSkills: [];

  signal handcardsSorted()
  signal selfChanged()

  // 交换两个idx的卡牌，用于拖拽排序
  function swapHandcard(fromIdx, toIdx) {
    const from = handcards[fromIdx];
    const to = handcards[toIdx];
    if (!from || !to) return;
    handcards.splice(toIdx, 1);
    handcards.splice(fromIdx, 0, to);
  }

  function sortHandcards(sortMethod) {
    const typeSorter = (a, b) => {
      if (a.type !== b.type) return a.type - b.type;
      if (a.subtype !== b.subtype) {
        const subtypeInt = {
          ["none"]: Ltk.Card.SubtypeNone,
          ["delayed_trick"]: Ltk.Card.SubtypeDelayedTrick,
          ["weapon"]: Ltk.Card.SubtypeWeapon,
          ["armor"]: Ltk.Card.SubtypeArmor,
          ["defensive_ride"]: Ltk.Card.SubtypeDefensiveRide,
          ["offensive_ride"]: Ltk.Card.SubtypeOffensiveRide,
          ["treasure"]: Ltk.Card.SubtypeTreasure,
        }
        return subtypeInt[a.subtype] - subtypeInt[b.subtype];
      }
      if (a.trueName !== b.trueName) {
        return a.trueName.localeCompare(b.trueName);
      } else if (a.name !== b.name) {
        if (a.name === a.trueName && b.name !== b.trueName) return -1;
        if (a.name !== a.trueName && b.name === b.trueName) return 1; // 让trueName和name一致的排在前（slash在thunder__slash和fire__slash前）
        return a.name.localeCompare(b.name);
      }
      return 0;
    };

    const numberSorter = (a, b) => {
      if (a.number !== b.number) return a.number - b.number;
      return 0;
    };

    const suitSorter = (a, b) => {
      const suitInt = {
        spade: 1, heart: 3,
        club: 2, diamond: 4,
      };
      if (a.suit !== b.suit) return suitInt[a.suit] - suitInt[b.suit];
      return 0;
    };

    const compareCards = (a, b, order) => {
      for (const compare of order) {
        const res = compare(a, b);
        if (res !== 0) return res;
      }

      return a.cardId - b.cardId;
    };

    const sortByType = (a, b) => compareCards(a, b, [
      typeSorter,
      suitSorter,
      numberSorter,
    ]);

    const sortByNumber = (a, b) => compareCards(a, b, [
      numberSorter,
      typeSorter,
      suitSorter,
    ]);

    const sortBySuit = (a, b) => compareCards(a, b, [
      suitSorter,
      typeSorter,
      numberSorter,
    ]);

    // sortMethod: 0=type, 1=number, 2=suit
    if (sortMethod === 0) {
      handcards.sort(sortByType);
    } else if (sortMethod === 1) {
      handcards.sort(sortByNumber);
    } else if (sortMethod === 2) {
      handcards.sort(sortBySuit);
    }

    handcardsSorted();
  }

  function addSkill(skill_name, prelight) {
    const model = Ltk.createSkillModel(skill_name);
    const arr = prelight ? fakeSkills : skills;
    if (prelight) {
      model.isPrelight = true;
      model.enabled = true;
    }

    if (!arr.find(e => e.origName === skill_name)) {
      arr.push(model);
      if (prelight) {
        model.selectedChanged.connect(() => {
          if (!model.selected) return;
          model.enabled = false;
          ClientInstance.notifyServer("PushRequest", [
            "prelight", model.origName, (!model.prelighted).toString()
          ].join(","));
        });
      } else {
        model.selectedChanged.connect(() => {
          if (model.enabled) roomScene.activateSkill(model.origName, model.selected, "click");
        });
      }
    }
    return;
  }

  function loseSkill(skill_name, prelight) {
    const arr = prelight ? fakeSkills : skills;
    const idx = arr.findIndex(e => e.origName === skill_name);
    if (idx !== -1) arr.splice(idx, 1);
  }

  function prelightSkill(skill_name, prelight) {
    const model = fakeSkills.find(e => e.origName === skill_name);
    if (model) {
      model.prelighted = prelight;
      model.enabled = true;
      model.selected = false;
    }
  }

  function disableAllSkills() {
    for (const model of skills) {
      model.enabled = false;
    }
  }

  function changeSelf() {
    const self = Lua.selfPlayer;
    const ids = self.getCardIds("h");
    handcards = ids.map(id => Ltk.createCardModel(id, { known: self.cardVisible(id) }));
    expandedCards = [];

    skills = [];
    fakeSkills = [];
    for (const s of self.player_skills) {
      if (s.visible) {
        addSkill(s.name);
      }
    }

    selfChanged();
  }

  function refreshData() {
    // const sortable = Ltk.canSortHandcards(Cpp.self.id);
    // dashboard.sortable = sortable;
    // dashboard.handcardArea.sortable = sortable;
    const p = Lua.selfPlayer;
    for (const model of skills) {
      const skill = Ltk.getSkill(model.origName);
      model.nullified = !skill.isEffectable(p);
      model.times = skill.getTimes(p);
    }

    for (const model of handcards) {
      model.refreshData();
    }
  }

  function applyChange(uiUpdate) {
    uiUpdate["_delete"]?.forEach(data => {
      if (data.type !== "CardItem") return;
      const idx = expandedCards.findIndex(e => e.uniqueId === data.id);
      if (idx !== -1) expandedCards.splice(idx, 1);
    });

    uiUpdate["_new"]?.forEach(dat => {
      if (dat.type !== "CardItem") return;
      let card;
      if (dat.data.card) {
        card = Ltk.createCardModelFromLuaValue(dat.data.card);
      } else {
        card = Ltk.createCardModel(dat.data.id);
      }
      card.footnote = Lua.tr(dat.ui_data.footnote);
      card.footnoteVisible = true;
      card.updateCardTip();
      const vcard = Ltk.getVirtualEquipData(0, dat.data.id);
      if (vcard) card.virtName = vcard.name;
      expandedCards.push(card);
    });

    uiUpdate["CardItem"]?.forEach(cdata => {
      const card = handcards.find(e => e.uniqueId === cdata.id) ||
        expandedCards.find(e => e.uniqueId === cdata.id);

      if (card) {
        card.selectable = cdata.enabled;
        card.selected = cdata.selected;
      }
    });

    for (const card of handcards) {
      card.updateCardTip();
      if (!card.selectable) {
        card.prohibitReason = Ltk.getCardProhibitReason(card.cardId);
      }
    }

    uiUpdate["SkillButton"]?.forEach(skdata => {
      const skillBtn = skills.find(e => e.origName === skdata.id);
      if (skillBtn) {
        skillBtn.enabled = skdata.enabled;
        skillBtn.selected = skdata.selected;
      }
    });

    if (uiUpdate["visible_cards"]) {
      visible_ids = uiUpdate["visible_cards"];
    } else {
      visible_ids = []
    }
  }
}
