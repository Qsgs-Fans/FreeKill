// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Components

pragma ComponentBehavior: Bound

MetroButton {
  id: root

  // 用来创建组件的清单数组，每一项的内容：
  // * { type: "card", cid: <id> } 创建一张卡牌。
  // * { type: "card", name: <name> } 创建一张卡牌（牌名）。
  // * { type: "general", name: <name> } 创建一张武将牌。
  // * { qml: <QmlComponent>, answer: string } 想创建啥就创建啥，需要自己指定想传给服务端的answer。
  property var specList: []
  property var expandItems: []
  property var selectedSpec
  property string answer

  property bool asking: false

  enabled: !asking

  text: {
    if (!selectedSpec) return Lua.tr("AskForChoices");
    // TODO 若为id则toLogString一下
    return Ltk.processPrompt(answer)
  }

  onAnswerChanged: {
    if (!answer) return;
    Lua.updateRequestUI("Interaction", "1", "update", answer);
  }

  function clear() {
    const handArea = Ltk.roomScene.dashboard.handcardArea;
    handArea.clearMiscExpand();
  }

  onClicked: {
    asking = true;
    expandItems = [];
    const handArea = Ltk.roomScene.dashboard.handcardArea;
    const cardComponent = Qt.createComponent("LunarLtk.Components", "CardItem");
    for (const spec of specList) {
      if (spec.type === "card") {
        let dataModel;
        if (spec.cid) {
          dataModel = Ltk.createCardModel(spec.cid);
        } else if (spec.name) {
          dataModel = Ltk.createCardModelFromName(spec.name);
        }
        const item = cardComponent.createObject(Ltk.roomScene, { dataModel }) as CardItem;
        item.selectable = true;
        item.clicked.connect(() => {
          selectedSpec = spec;
          answer = spec.cid || spec.name;
          asking = false;
          handArea.clearMiscExpand();
        });
        expandItems.push(item);
      } else if (spec.type === "general") {
        // TODO
      } else if (spec.qml) {
        // TODO
      }
    }
    handArea.addMiscExpand(expandItems);
  }
}

