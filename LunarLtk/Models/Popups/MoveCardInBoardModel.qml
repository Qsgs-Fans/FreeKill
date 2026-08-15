// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import LunarLtk

QtObject {
  id: root

  property list<int> cardIds // int[] 卡牌id数组
  property list<int> cardsPosition // 0/1的数组 0表示cardIds[i]属于玩家A 1反之
  property list<int> playerIds // [玩家Aid，玩家Bid]
  property string prompt: ""

  property int result: -1

  readonly property var cardModels: {
    const dict = {};
    for (let i = 0; i < cardIds.length; i++) {
      const id = cardIds[i];
      const cardPos = cardsPosition[i];
      const vcard = Ltk.getVirtualEquipData(playerIds[cardPos], id);
      dict[id] = Ltk.createCardModel(id, {
        virtName: vcard?.name ?? "",
      });
    }
    return dict;
  }

  readonly property bool feasible: result !== -1

  readonly property string promptText: {
    return Ltk.processPrompt(prompt)
  }

  signal accepted()
  signal rejected()
}
